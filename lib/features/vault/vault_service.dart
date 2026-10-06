import 'package:cryptography/cryptography.dart';
import 'package:flutter/foundation.dart';
import 'package:sqflite_sqlcipher/sqflite.dart';

import '../../core/crypto/kdf.dart';
import '../../core/crypto/tag_hmac.dart';
import '../../core/crypto/vault_crypto.dart';
import '../../core/logging/app_logger.dart';
import '../../core/storage/blob_store.dart';
import '../../core/storage/paths.dart';
import '../../core/storage/vault_database.dart';
import 'key_rotation_journal.dart';
import 'vault_descriptor.dart';
import 'vault_key_migrator.dart';

enum VaultState { uninitialized, locked, unlocked }

class VaultService extends ChangeNotifier {
  VaultService({required VaultPaths paths})
      : _paths = paths,
        _crypto = VaultCrypto(),
        blobStore = BlobStore(paths);

  final VaultPaths _paths;
  final VaultCrypto _crypto;
  final BlobStore blobStore;

  VaultDatabase? _vaultDb;
  SecretKey? _kek;
  SecretKey? _tagHmacKey;

  VaultState get state {
    if (!VaultDescriptor.exists(_paths)) return VaultState.uninitialized;
    if (_vaultDb == null || _kek == null) return VaultState.locked;
    return VaultState.unlocked;
  }

  VaultCrypto get crypto => _crypto;

  Database get db {
    final v = _vaultDb;
    if (v == null) {
      throw StateError('Vault is locked');
    }
    return v.db;
  }

  SecretKey get kek {
    final k = _kek;
    if (k == null) throw StateError('Vault is locked');
    return k;
  }

  TagHmac get tagHmac {
    final k = _tagHmacKey;
    if (k == null) throw StateError('Vault is locked');
    return TagHmac(k);
  }

  Future<void> initialize(String masterPassword) async {
    if (VaultDescriptor.exists(_paths)) {
      throw StateError('Vault already initialized');
    }
    final descriptor = VaultDescriptor.createFresh();
    final kek = await Kdf(params: descriptor.kdf).deriveKek(
      password: masterPassword,
      salt: descriptor.salt,
    );
    final dbPassword = await kekToDbPassword(kek);
    final vaultDb = await VaultDatabase.open(
      path: _paths.databasePath,
      password: dbPassword,
    );
    await descriptor.save(_paths);

    _vaultDb = vaultDb;
    _kek = kek;
    _tagHmacKey = await deriveTagHmacKey(kek);
    notifyListeners();
  }

  Future<bool> unlock(String masterPassword) async {
    if (!VaultDescriptor.exists(_paths)) {
      throw StateError('Vault not initialized');
    }
    
    // A password change was interrupted: finish it toward whichever
    // password the user typed.
    final journal = await KeyRotationJournal.load(_paths);
    if (journal != null) {
      for (final d in [journal.oldDescriptor, journal.newDescriptor]) {
        final kek = await Kdf(params: d.kdf).deriveKek(
          password: masterPassword,
          salt: d.salt,
        );
        if (await _completeRotation(journal, kek)) return true;
      }
      return false;
    }

    // 1. Try with primary descriptor
    final descriptor = await VaultDescriptor.load(_paths);
    if (await _tryOpen(masterPassword, descriptor)) {
      // Success - if a backup existed, it's now stale
      await VaultDescriptor.deleteBackup(_paths);
      return true;
    }

    // 2. Recovery: Try with backup descriptor (in case rotation failed)
    final backup = await VaultDescriptor.loadBackup(_paths);
    if (backup != null) {
      if (await _tryOpen(masterPassword, backup)) {
        // We recovered using the old salt! 
        // This means the DB re-key either failed or didn't happen.
        // We should keep the backup until the next successful rotation attempt.
        return true;
      }
    }

    return false;
  }

  Future<bool> _tryOpen(String password, VaultDescriptor descriptor) async {
    final kek = await Kdf(params: descriptor.kdf).deriveKek(
      password: password,
      salt: descriptor.salt,
    );
    final dbPassword = await kekToDbPassword(kek);
    try {
      final vaultDb = await VaultDatabase.open(
        path: _paths.databasePath,
        password: dbPassword,
      );
      _vaultDb = vaultDb;
      _kek = kek;
      _tagHmacKey = await deriveTagHmacKey(kek);
      notifyListeners();
      return true;
    } catch (e, st) {
      // Expected on wrong password (SQLCipher fails to open the encrypted DB);
      // log at debug so real errors elsewhere still surface.
      log.d('[vault] _tryOpen failed', error: e, stackTrace: st);
      return false;
    }
  }

  /// Brings an interrupted key rotation to a consistent state under [kek]
  /// and opens the vault with it. Returns false if [kek] matches neither
  /// side of the journal.
  Future<bool> _completeRotation(KeyRotationJournal journal, SecretKey kek) async {
    final keys = await journal.resolve(kek);
    if (keys == null) return false;
    final migrator = VaultKeyMigrator(target: keys.target, other: keys.other);
    final vaultDb = await migrator.open(_paths.databasePath);
    try {
      await migrator.rewrapAll(vaultDb.db);
      await keys.descriptor.save(_paths);
      await KeyRotationJournal.delete(_paths);
      await VaultDescriptor.deleteBackup(_paths);
    } catch (_) {
      await vaultDb.close();
      rethrow;
    }
    _vaultDb = vaultDb;
    _kek = keys.target;
    _tagHmacKey = await deriveTagHmacKey(keys.target);
    notifyListeners();
    return true;
  }

  /// Called when a password change fails part-way: closes the DB and rolls
  /// the vault back to [oldKek]. If even that fails the vault stays locked
  /// and the journal makes the next unlock finish the job.
  Future<void> abortRotation(SecretKey oldKek) async {
    final v = _vaultDb;
    _vaultDb = null;
    _kek = null;
    _tagHmacKey = null;
    try {
      await v?.close();
    } catch (e, st) {
      log.w('[vault] closing DB during rotation rollback failed',
          error: e, stackTrace: st);
    }
    try {
      final journal = await KeyRotationJournal.load(_paths);
      if (journal != null && await _completeRotation(journal, oldKek)) return;
    } catch (e, st) {
      log.e('[vault] rotation rollback failed; vault left locked',
          error: e, stackTrace: st);
    }
    notifyListeners();
  }

  void notifyExternalChange() => notifyListeners();

  /// Confirms that [password] derives the same KEK as the one currently held in
  /// memory. Does not touch the open DB handle. Used by settings screens that
  /// need to prove the user knows the master password (e.g. before storing it
  /// for biometric unlock).
  Future<bool> verifyPassword(String password) async {
    final current = _kek;
    if (current == null) return false;
    final descriptor = await VaultDescriptor.load(_paths);
    final candidate = await Kdf(params: descriptor.kdf).deriveKek(
      password: password,
      salt: descriptor.salt,
    );
    final a = await current.extractBytes();
    final b = await candidate.extractBytes();
    if (a.length != b.length) return false;
    var diff = 0;
    for (var i = 0; i < a.length; i++) {
      diff |= a[i] ^ b[i];
    }
    return diff == 0;
  }

  Future<void> lock() async {
    final v = _vaultDb;
    _vaultDb = null;
    _kek = null;
    _tagHmacKey = null;
    await v?.close();
    notifyListeners();
  }

  Future<void> destroy() async {
    final v = _vaultDb;
    _vaultDb = null;
    _kek = null;
    _tagHmacKey = null;
    await v?.close();

    final root = _paths.root;
    if (root.existsSync()) {
      root.deleteSync(recursive: true);
    }
    root.createSync(recursive: true);
    _paths.blobsDir.createSync(recursive: true);

    notifyListeners();
  }

  void updateKeysAfterRotation(SecretKey newKek, SecretKey newTagHmacKey) {
    _kek = newKek;
    _tagHmacKey = newTagHmacKey;
    notifyListeners();
  }
}
