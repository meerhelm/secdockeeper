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

/// Owns the in-memory secret material and the open DB handle for the currently
/// unlocked vault.
///
/// There is one **primary** vault (created at onboarding) and at most one
/// optional **hidden** vault (a plausible-deniability vault stored in a
/// separate, unlisted directory). At the lock screen the entered password is
/// tried against the primary descriptor first and then the hidden one, so
/// typing the hidden vault's password transparently opens the hidden vault.
/// `_active` tracks which vault is currently open; `blobStore`, `db` and the
/// keys all follow it.
class VaultService extends ChangeNotifier {
  VaultService({required VaultPaths paths, required VaultPaths hiddenPaths})
      : _primaryPaths = paths,
        _hiddenPaths = hiddenPaths,
        _crypto = VaultCrypto(),
        _active = paths,
        _blobStore = BlobStore(paths);

  final VaultPaths _primaryPaths;
  final VaultPaths _hiddenPaths;
  final VaultCrypto _crypto;

  VaultPaths _active;
  BlobStore _blobStore;

  // AAD binding the wrapped VMK to its purpose, so a wrapped VMK can never be
  // mistaken for (or swapped with) any other AES-GCM blob in the vault.
  static final List<int> _vmkAad = utf8.encode('secdockeeper:vmk:v1');

  VaultDatabase? _vaultDb;
  SecretKey? _kek;
  SecretKey? _vmk; // v2 only — null for legacy v1 vaults
  SecretKey? _wrapKey; // wraps DEKs + encrypts hidden-tag names
  SecretKey? _tagHmacKey;

  /// Blob store for the **currently active** vault.
  BlobStore get blobStore => _blobStore;

  VaultState get state {
    // Any open vault (primary or hidden) reads as unlocked.
    if (_vaultDb != null && _kek != null) return VaultState.unlocked;
    if (!VaultDescriptor.exists(_primaryPaths)) return VaultState.uninitialized;
    return VaultState.locked;
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

  /// Whether a hidden vault exists on disk. Used by the duress wipe; not
  /// surfaced in normal UI.
  bool get hasHiddenVault => VaultDescriptor.exists(_hiddenPaths);

  /// True when the currently open vault is the hidden one.
  bool get activeIsHidden => identical(_active, _hiddenPaths);

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

  void _setActive(VaultPaths paths) {
    _active = paths;
    _blobStore = BlobStore(paths);
  }

  Future<void> initialize(String masterPassword) async {
    if (VaultDescriptor.exists(_primaryPaths)) {
      throw StateError('Vault already initialized');
    }
    _setActive(_primaryPaths);
    final opened = await _createVaultAt(_primaryPaths, masterPassword, keepOpen: true);
    _vaultDb = opened.db;
    _kek = opened.kek;
    _vmk = opened.vmk;
    _wrapKey = opened.wrapKey;
    _tagHmacKey = opened.tagHmacKey;
    notifyListeners();
  }

  /// Creates (or silently replaces) the hidden vault on disk **without**
  /// disturbing the currently open session. The hidden vault is opened only to
  /// lay down its schema, then closed again.
  Future<void> createHiddenVault(String masterPassword) async {
    if (VaultDescriptor.exists(_hiddenPaths)) {
      await destroyHidden();
    }
    final opened = await _createVaultAt(_hiddenPaths, masterPassword, keepOpen: false);
    await opened.db?.close();
  }

  Future<bool> unlock(String masterPassword) async {
    // 1. Primary vault.
    if (VaultDescriptor.exists(_primaryPaths)) {
      final primaryDesc = await VaultDescriptor.load(_primaryPaths);
      if (await _tryOpenAt(masterPassword, _primaryPaths, primaryDesc)) {
        await VaultDescriptor.deleteBackup(_primaryPaths);
        return true;
      }
    } else {
      throw StateError('Vault not initialized');
    }

    // 2. Hidden vault — opened by typing its own password into the same prompt.
    if (VaultDescriptor.exists(_hiddenPaths)) {
      final hiddenDesc = await VaultDescriptor.load(_hiddenPaths);
      if (await _tryOpenAt(masterPassword, _hiddenPaths, hiddenDesc)) {
        return true;
      }
    }

    // 3. Recovery: primary rotation backup descriptor (rotation crash window).
    final backup = await VaultDescriptor.loadBackup(_primaryPaths);
    if (backup != null && await _tryOpenAt(masterPassword, _primaryPaths, backup)) {
      return true;
    }

    return false;
  }

  Future<bool> _tryOpenAt(
    String password,
    VaultPaths paths,
    VaultDescriptor descriptor,
  ) async {
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
        dbPassword = await _kekToDbPassword(kek);
        wrapKey = kek;
        tagKeyInput = kek;
      }

      final vaultDb = await VaultDatabase.open(
        path: paths.databasePath,
        password: dbPassword,
      );
      _vaultDb = vaultDb;
      _kek = kek;
      _vmk = vmk;
      _wrapKey = wrapKey;
      _tagHmacKey = await deriveTagHmacKey(tagKeyInput);
      _setActive(paths);
      notifyListeners();
      return true;
    } catch (e, st) {
      // Expected on wrong password (VMK unwrap or SQLCipher open fails); log at
      // debug so genuine errors elsewhere still surface.
      log.d('[vault] _tryOpenAt failed', error: e, stackTrace: st);
      return false;
    }
  }

  void notifyExternalChange() => notifyListeners();

  /// Confirms [password] derives the same KEK as the active vault's.
  Future<bool> verifyPassword(String password) async {
    final current = _kek;
    if (current == null) return false;
    final descriptor = await VaultDescriptor.load(_active);
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

  /// O(1) crash-safe password rotation for the active v2 vault: re-wrap the VMK
  /// under a KEK derived from the new password and rewrite `vault.json`.
  Future<void> rotatePasswordV2(String newMasterPassword) async {
    final vmk = _vmk;
    if (vmk == null) {
      throw StateError('rotatePasswordV2 requires an unlocked v2 vault');
    }
    final oldDescriptor = await VaultDescriptor.load(_active);
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

    await VaultDescriptor.backup(_active);
    await newDescriptor.save(_active);
    await VaultDescriptor.deleteBackup(_active);

    _kek = newKek;
    notifyListeners();
  }

  Future<void> lock() async {
    await _clearKeysAndClose();
    _setActive(_primaryPaths);
    notifyListeners();
  }

  /// Destroys the **primary** vault (and resets to onboarding). The hidden
  /// vault, if any, is intentionally left untouched here — it has its own
  /// lifecycle (duress wipe / explicit replacement).
  Future<void> destroy() async {
    await _clearKeysAndClose();
    _setActive(_primaryPaths);

    final root = _primaryPaths.root;
    if (root.existsSync()) {
      root.deleteSync(recursive: true);
    }
    root.createSync(recursive: true);
    _primaryPaths.blobsDir.createSync(recursive: true);

    notifyListeners();
  }

  /// Removes the hidden vault from disk, ignoring all normal panic/lockout
  /// rules. Safe to call when locked (the common duress case) — it just deletes
  /// the directory. If the hidden vault happens to be the open one, it is locked
  /// first.
  Future<void> destroyHidden() async {
    if (activeIsHidden && _vaultDb != null) {
      await _clearKeysAndClose();
      _setActive(_primaryPaths);
      notifyListeners();
    }
    final root = _hiddenPaths.root;
    if (root.existsSync()) {
      root.deleteSync(recursive: true);
    }
  }

  /// Updates live key state after a legacy v1 rotation (DEK re-wrap + DB rekey).
  /// v2 vaults rotate via [rotatePasswordV2] and do not call this.
  void updateKeysAfterRotation(SecretKey newKek, SecretKey newTagHmacKey) {
    _kek = newKek;
    _wrapKey = newKek; // v1: the KEK is the wrap key
    _tagHmacKey = newTagHmacKey;
    notifyListeners();
  }

  Future<void> _clearKeysAndClose() async {
    final v = _vaultDb;
    _vaultDb = null;
    _kek = null;
    _vmk = null;
    _wrapKey = null;
    _tagHmacKey = null;
    await v?.close();
  }

  /// Lays down a fresh v2 vault (descriptor + schema) at [paths]. Returns the
  /// derived keys and, when [keepOpen], the open DB handle (otherwise the caller
  /// is responsible for closing `db`).
  Future<_OpenedVault> _createVaultAt(
    VaultPaths paths,
    String masterPassword, {
    required bool keepOpen,
  }) async {
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
      path: paths.databasePath,
      password: dbPassword,
    );
    await descriptor.save(paths);
    return _OpenedVault(
      db: vaultDb,
      kek: kek,
      vmk: vmk,
      wrapKey: await deriveWrapKey(vmk),
      tagHmacKey: await deriveTagHmacKey(vmk),
    );
  }

  static Future<String> _kekToDbPassword(SecretKey kek) async {
    final bytes = await kek.extractBytes();
    return base64Encode(bytes);
  }
}

class _OpenedVault {
  _OpenedVault({
    required this.db,
    required this.kek,
    required this.vmk,
    required this.wrapKey,
    required this.tagHmacKey,
  });

  final VaultDatabase? db;
  final SecretKey kek;
  final SecretKey vmk;
  final SecretKey wrapKey;
  final SecretKey tagHmacKey;
}
