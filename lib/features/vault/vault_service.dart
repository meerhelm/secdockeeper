import 'dart:convert';

import 'package:cryptography/cryptography.dart';
import 'package:flutter/foundation.dart';
import 'package:sqflite_sqlcipher/sqflite.dart';

import '../../core/crypto/kdf.dart';
import '../../core/crypto/tag_hmac.dart';
import '../../core/crypto/vault_crypto.dart';
import '../../core/crypto/vault_keys.dart';
import '../../core/logging/app_logger.dart';
import '../../core/storage/blob_store.dart';
import '../../core/storage/paths.dart';
import '../../core/storage/vault_database.dart';
import 'vault_descriptor.dart';

enum VaultState { uninitialized, locked, unlocked }

class VaultService extends ChangeNotifier {
  VaultService({required VaultPaths paths})
      : _paths = paths,
        _crypto = VaultCrypto(),
        blobStore = BlobStore(paths);

  final VaultPaths _paths;
  final VaultCrypto _crypto;
  final BlobStore blobStore;

  // AAD binding the wrapped VMK to its purpose, so a wrapped VMK can never be
  // mistaken for (or swapped with) any other AES-GCM blob in the vault.
  static final List<int> _vmkAad = utf8.encode('secdockeeper:vmk:v1');

  VaultDatabase? _vaultDb;
  SecretKey? _kek;
  SecretKey? _vmk; // v2 only — null for legacy v1 vaults
  SecretKey? _wrapKey; // wraps DEKs + encrypts hidden-tag names
  SecretKey? _tagHmacKey;

  VaultState get state {
    if (!VaultDescriptor.exists(_paths)) return VaultState.uninitialized;
    if (_vaultDb == null || _kek == null) return VaultState.locked;
    return VaultState.unlocked;
  }

  VaultCrypto get crypto => _crypto;

  /// True once unlocked on a version-2 (VMK-backed) vault. Drives the choice of
  /// rotation strategy and is false for legacy v1 vaults.
  bool get usesVmk => _vmk != null;

  /// The crypto format new rows should be written at. Only VMK-backed (v2)
  /// vaults use AAD-bound rows; legacy v1 vaults keep writing un-bound rows so
  /// the legacy heavy-rotation path (which re-wraps DEKs without AAD) stays
  /// correct. New vaults are always v2.
  int get rowFormatVersion => usesVmk ? kCurrentRowFormatVersion : 1;

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

  /// The key that wraps per-document/-note DEKs and encrypts hidden-tag names.
  /// For v2 vaults this is HKDF-derived from the VMK; for v1 vaults it is the
  /// KEK itself, so legacy data keeps decrypting unchanged.
  SecretKey get wrapKey {
    final k = _wrapKey;
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
    // New vaults are always version 2 (VMK-backed).
    final base = VaultDescriptor.createFresh();
    final kek = await Kdf(params: base.kdf).deriveKek(
      password: masterPassword,
      salt: base.salt,
    );

    final vmk = SecretKey(randomBytes(32));
    final wrapped = await _crypto.wrapDek(kek: kek, dek: vmk, aad: _vmkAad);
    final descriptor = base.withWrappedVmk(WrappedVmk(
      nonce: wrapped.nonce,
      ciphertext: wrapped.ciphertext,
      mac: wrapped.mac,
    ));

    final dbKey = await deriveDbKey(vmk);
    final dbPassword = base64Encode(await dbKey.extractBytes());
    final vaultDb = await VaultDatabase.open(
      path: _paths.databasePath,
      password: dbPassword,
    );
    await descriptor.save(_paths);

    _vaultDb = vaultDb;
    _kek = kek;
    _vmk = vmk;
    _wrapKey = await deriveWrapKey(vmk);
    _tagHmacKey = await deriveTagHmacKey(vmk);
    notifyListeners();
  }

  Future<bool> unlock(String masterPassword) async {
    if (!VaultDescriptor.exists(_paths)) {
      throw StateError('Vault not initialized');
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
        // We recovered using the pre-rotation descriptor. Keep the backup until
        // the next successful rotation supersedes it.
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
    try {
      SecretKey? vmk;
      String dbPassword;
      SecretKey wrapKey;
      SecretKey tagKeyInput;

      if (descriptor.usesVmk) {
        // A wrong password fails the AES-GCM tag here, before we touch the DB.
        final w = descriptor.wrappedVmk!;
        vmk = await _crypto.unwrapDek(
          kek: kek,
          wrapped: WrappedDek(nonce: w.nonce, ciphertext: w.ciphertext, mac: w.mac),
          aad: _vmkAad,
        );
        final dbKey = await deriveDbKey(vmk);
        dbPassword = base64Encode(await dbKey.extractBytes());
        wrapKey = await deriveWrapKey(vmk);
        tagKeyInput = vmk;
      } else {
        // Legacy v1: KEK is the DB passphrase and the DEK-wrap key.
        dbPassword = await _kekToDbPassword(kek);
        wrapKey = kek;
        tagKeyInput = kek;
      }

      final vaultDb = await VaultDatabase.open(
        path: _paths.databasePath,
        password: dbPassword,
      );
      _vaultDb = vaultDb;
      _kek = kek;
      _vmk = vmk;
      _wrapKey = wrapKey;
      _tagHmacKey = await deriveTagHmacKey(tagKeyInput);
      notifyListeners();
      return true;
    } catch (e, st) {
      // Expected on wrong password (VMK unwrap or SQLCipher open fails); log at
      // debug so genuine errors elsewhere still surface.
      log.d('[vault] _tryOpen failed', error: e, stackTrace: st);
      return false;
    }
  }

  void notifyExternalChange() => notifyListeners();

  /// Confirms that [password] derives the same KEK as the one currently held in
  /// memory. Does not touch the open DB handle.
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

  /// O(1) crash-safe password rotation for v2 vaults: re-wrap the VMK under a
  /// KEK derived from the new password and rewrite `vault.json`. The DB
  /// passphrase, every wrapped DEK and all tag hashes are derived from the
  /// (unchanged) VMK, so none of them move.
  Future<void> rotatePasswordV2(String newMasterPassword) async {
    final vmk = _vmk;
    if (vmk == null) {
      throw StateError('rotatePasswordV2 requires an unlocked v2 vault');
    }
    final oldDescriptor = await VaultDescriptor.load(_paths);
    final newSalt = randomBytes(16);
    final newKek = await Kdf(params: oldDescriptor.kdf).deriveKek(
      password: newMasterPassword,
      salt: newSalt,
    );
    final wrapped = await _crypto.wrapDek(kek: newKek, dek: vmk, aad: _vmkAad);
    final newDescriptor = oldDescriptor.rotated(
      newSalt: newSalt,
      newWrappedVmk: WrappedVmk(
        nonce: wrapped.nonce,
        ciphertext: wrapped.ciphertext,
        mac: wrapped.mac,
      ),
    );

    // Keep the old descriptor recoverable across the single-file write.
    await VaultDescriptor.backup(_paths);
    await newDescriptor.save(_paths);
    await VaultDescriptor.deleteBackup(_paths);

    _kek = newKek;
    notifyListeners();
  }

  Future<void> lock() async {
    final v = _vaultDb;
    _vaultDb = null;
    _kek = null;
    _vmk = null;
    _wrapKey = null;
    _tagHmacKey = null;
    await v?.close();
    notifyListeners();
  }

  Future<void> destroy() async {
    final v = _vaultDb;
    _vaultDb = null;
    _kek = null;
    _vmk = null;
    _wrapKey = null;
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

  /// Updates live key state after a legacy v1 rotation (DEK re-wrap + DB rekey).
  /// v2 vaults rotate via [rotatePasswordV2] and do not call this.
  void updateKeysAfterRotation(SecretKey newKek, SecretKey newTagHmacKey) {
    _kek = newKek;
    _wrapKey = newKek; // v1: the KEK is the wrap key
    _tagHmacKey = newTagHmacKey;
    notifyListeners();
  }

  static Future<String> _kekToDbPassword(SecretKey kek) async {
    final bytes = await kek.extractBytes();
    return base64Encode(bytes);
  }
}
