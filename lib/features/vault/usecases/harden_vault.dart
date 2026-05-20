import 'dart:convert';

import '../../../core/crypto/aead.dart';
import '../../../core/crypto/kdf.dart';
import '../../../core/crypto/tag_hmac.dart';
import '../../../core/crypto/vault_crypto.dart';
import '../../../core/logging/app_logger.dart';
import '../../../core/storage/paths.dart';
import '../../../core/storage/vault_database.dart';
import '../../documents/document_repository.dart';
import '../../hidden_tags/hidden_tag_repository.dart';
import '../../notes/note_repository.dart';
import '../vault_descriptor.dart';
import '../vault_service.dart';

/// Re-derives the KEK under stronger Argon2id parameters while keeping the
/// master password unchanged, then re-wraps every DEK and re-keys SQLCipher.
///
/// Differs from [RotateVaultKeyUseCase] in two ways:
///   * the user's password is unchanged — we re-verify it instead of accepting
///     a new one,
///   * the new vault.json descriptor is written **before** `PRAGMA rekey` runs.
///     With an unchanged password this ordering survives a mid-rotation kill:
///     the user's password still derives the *old* KEK from `vault.json.bak`,
///     which still matches the unmodified DB.
class HardenVaultUseCase {
  HardenVaultUseCase({
    required VaultService vault,
    required DocumentRepository documents,
    required HiddenTagRepository hiddenTags,
    required NoteRepository notes,
    required VaultPaths paths,
  })  : _vault = vault,
        _documents = documents,
        _hiddenTags = hiddenTags,
        _notes = notes,
        _paths = paths;

  final VaultService _vault;
  final DocumentRepository _documents;
  final HiddenTagRepository _hiddenTags;
  final NoteRepository _notes;
  final VaultPaths _paths;

  Future<void> call({
    required String currentPassword,
    required KdfParams targetParams,
  }) async {
    if (_vault.state != VaultState.unlocked) {
      throw StateError('Vault must be unlocked to harden');
    }
    final passwordOk = await _vault.verifyPassword(currentPassword);
    if (!passwordOk) {
      throw const HardenVaultError('Incorrect master password.');
    }

    final oldKek = _vault.kek;
    final oldDescriptor = await VaultDescriptor.load(_paths);

    if (!_isUpgrade(oldDescriptor.kdf, targetParams)) {
      throw const HardenVaultError(
        'Target parameters are not stronger than the current vault.',
      );
    }

    // Snapshot vault.json before any mutation — recovery anchor.
    await VaultDescriptor.backup(_paths);

    try {
      // 1. Derive the new KEK + tag HMAC key under the target params.
      final newSalt = randomBytes(16);
      final newKek = await Kdf(params: targetParams).deriveKek(
        password: currentPassword,
        salt: newSalt,
      );
      final newTagHmacKey = await deriveTagHmacKey(newKek);
      final newTagHmac = TagHmac(newTagHmacKey);

      // 2. Re-wrap every DEK and hidden-tag entry under newKek.
      final crypto = _vault.crypto;
      final docUpdates = <int, WrappedDek>{};
      for (final entry in (await _documents.getAllCrypto()).entries) {
        final dek = await crypto.unwrapDek(
          kek: oldKek,
          wrapped: WrappedDek(
            nonce: entry.value.dekNonce,
            ciphertext: entry.value.dekWrapped,
            mac: entry.value.dekMac,
          ),
        );
        docUpdates[entry.key] = await crypto.wrapDek(kek: newKek, dek: dek);
      }
      final noteUpdates = <int, WrappedDek>{};
      for (final entry in (await _notes.getAllCrypto()).entries) {
        final dek = await crypto.unwrapDek(
          kek: oldKek,
          wrapped: WrappedDek(
            nonce: entry.value.dekNonce,
            ciphertext: entry.value.dekWrapped,
            mac: entry.value.dekMac,
          ),
        );
        noteUpdates[entry.key] = await crypto.wrapDek(kek: newKek, dek: dek);
      }
      final hiddenTagUpdates = <HiddenTagUpdate>[];
      for (final entry in await _hiddenTags.getAllEntries()) {
        final nameBytes = await Aead.open(
          key: oldKek,
          sealed: SealedBytes(
            nonce: entry.encryptedNameNonce!,
            ciphertext: entry.encryptedName!,
            mac: entry.encryptedNameMac!,
          ),
        );
        final name = utf8.decode(nameBytes);
        final newSealed = await Aead.seal(key: newKek, plaintext: nameBytes);
        hiddenTagUpdates.add(HiddenTagUpdate(
          documentId: entry.documentId,
          oldTagHash: entry.tagHash,
          newTagHash: await newTagHmac.hash(name),
          newEncryptedName: newSealed.ciphertext,
          newEncryptedNameNonce: newSealed.nonce,
          newEncryptedNameMac: newSealed.mac,
        ));
      }

      // 3. Save the new descriptor *before* rekey.
      // Crash window: if we die between this save and the rekey below, the
      // primary descriptor advertises new params but the DB is still on the
      // old KEK. `VaultService.unlock` will then fall back to the .bak
      // descriptor (which still matches the DB) and the vault stays openable.
      final newDescriptor = VaultDescriptor(
        version: oldDescriptor.version,
        salt: newSalt,
        kdf: targetParams,
      );
      await newDescriptor.save(_paths);

      // 4. Update wrapped DEKs + hidden-tag index in a single DB transaction,
      // then rekey SQLCipher. The DB writes still go through the *old* db
      // password (since rekey hasn't happened yet); rekey swaps the cipher
      // key atomically for the open connection.
      final db = _vault.db;
      await db.transaction((txn) async {
        for (final entry in docUpdates.entries) {
          await txn.update(
            'documents',
            {
              'dek_wrapped': entry.value.ciphertext,
              'dek_nonce': entry.value.nonce,
              'dek_mac': entry.value.mac,
              'updated_at': DateTime.now().millisecondsSinceEpoch,
            },
            where: 'id = ?',
            whereArgs: [entry.key],
          );
        }
        for (final entry in noteUpdates.entries) {
          await txn.update(
            'notes',
            {
              'dek_wrapped': entry.value.ciphertext,
              'dek_nonce': entry.value.nonce,
              'dek_mac': entry.value.mac,
            },
            where: 'id = ?',
            whereArgs: [entry.key],
          );
        }
        for (final u in hiddenTagUpdates) {
          await txn.delete(
            'hidden_tag_index',
            where: 'document_id = ? AND tag_hash = ?',
            whereArgs: [u.documentId, u.oldTagHash],
          );
          await txn.insert('hidden_tag_index', {
            'tag_hash': u.newTagHash,
            'document_id': u.documentId,
            'encrypted_name': u.newEncryptedName,
            'encrypted_name_nonce': u.newEncryptedNameNonce,
            'encrypted_name_mac': u.newEncryptedNameMac,
          });
        }
      });

      final newDbPassword = base64Encode(await newKek.extractBytes());
      await VaultDatabase.fromRaw(db).rekey(newDbPassword);

      // 5. Swap live KEK + tag HMAC, then drop the recovery anchor.
      _vault.updateKeysAfterRotation(newKek, newTagHmacKey);
      await VaultDescriptor.deleteBackup(_paths);
    } catch (e, st) {
      log.e('[harden_vault] hardening failed', error: e, stackTrace: st);
      rethrow;
    }
  }

  static bool _isUpgrade(KdfParams from, KdfParams to) {
    if (to.memory < from.memory) return false;
    if (to.iterations < from.iterations) return false;
    if (to.parallelism < from.parallelism) return false;
    // Same params → no-op, reject so the caller doesn't pay an unlock cost.
    return to.memory > from.memory || to.iterations > from.iterations;
  }
}

class HardenVaultError implements Exception {
  const HardenVaultError(this.message);
  final String message;
  @override
  String toString() => message;
}
