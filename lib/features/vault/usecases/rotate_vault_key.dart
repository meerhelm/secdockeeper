import 'dart:convert';

import '../../../core/crypto/aead.dart';
import '../../../core/crypto/kdf.dart';
import '../../../core/crypto/tag_hmac.dart';
import '../../../core/crypto/vault_crypto.dart';
import '../../../core/storage/paths.dart';
import '../../../core/storage/vault_database.dart';
import '../../documents/document_repository.dart';
import '../../hidden_tags/hidden_tag_repository.dart';
import '../../notes/note_repository.dart';
import '../vault_descriptor.dart';
import '../vault_service.dart';

class RotateVaultKeyUseCase {
  RotateVaultKeyUseCase({
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

  Future<void> call(String newMasterPassword) async {
    if (_vault.state != VaultState.unlocked) {
      throw StateError('Vault must be unlocked to rotate keys');
    }

    final oldKek = _vault.kek;
    final oldDescriptor = await VaultDescriptor.load(_paths);

    // 1. Create a backup of the current descriptor
    await VaultDescriptor.backup(_paths);

    try {
      // 2. Derive new KEK and TagHMAC key
      final newSalt = randomBytes(16);
      final kdf = Kdf(params: oldDescriptor.kdf);
      final newKek = await kdf.deriveKek(
        password: newMasterPassword,
        salt: newSalt,
      );
      final newTagHmacKey = await deriveTagHmacKey(newKek);
      final newTagHmac = TagHmac(newTagHmacKey);

      // 3. Prepare DEK re-wrapping updates
      final crypto = _vault.crypto;
      final allCrypto = await _documents.getAllCrypto();
      final documentUpdates = <int, WrappedDek>{};
      for (final entry in allCrypto.entries) {
        final dek = await crypto.unwrapDek(
          kek: oldKek,
          wrapped: WrappedDek(
            nonce: entry.value.dekNonce,
            ciphertext: entry.value.dekWrapped,
            mac: entry.value.dekMac,
          ),
        );
        documentUpdates[entry.key] = await crypto.wrapDek(kek: newKek, dek: dek);
      }

      // 3b. Re-wrap note DEKs under the new KEK.
      final allNoteCrypto = await _notes.getAllCrypto();
      final noteUpdates = <int, WrappedDek>{};
      for (final entry in allNoteCrypto.entries) {
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

      // 4. Prepare Hidden Tag re-encryption and re-hashing updates
      final allHiddenTags = await _hiddenTags.getAllEntries();
      final hiddenTagUpdates = <HiddenTagUpdate>[];
      for (final entry in allHiddenTags) {
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

      // 5. Update Database Records
      final db = _vault.db;
      await db.transaction((txn) async {
        for (final update in documentUpdates.entries) {
          await txn.update(
            'documents',
            {
              'dek_wrapped': update.value.ciphertext,
              'dek_nonce': update.value.nonce,
              'dek_mac': update.value.mac,
              'updated_at': DateTime.now().millisecondsSinceEpoch,
            },
            where: 'id = ?',
            whereArgs: [update.key],
          );
        }

        for (final update in noteUpdates.entries) {
          await txn.update(
            'notes',
            {
              'dek_wrapped': update.value.ciphertext,
              'dek_nonce': update.value.nonce,
              'dek_mac': update.value.mac,
            },
            where: 'id = ?',
            whereArgs: [update.key],
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

      // 6. Change Database Password (Rekey)
      final newDbPasswordBytes = await newKek.extractBytes();
      final newDbPassword = base64Encode(newDbPasswordBytes);
      
      final vdb = VaultDatabase.fromRaw(db);
      await vdb.rekey(newDbPassword);

      // 7. Update Descriptor (vault.json)
      final newDescriptor = VaultDescriptor(
        version: oldDescriptor.version,
        salt: newSalt,
        kdf: oldDescriptor.kdf,
      );
      await newDescriptor.save(_paths);
      
      // 8. Update VaultService live state
      _vault.updateKeysAfterRotation(newKek, newTagHmacKey);

      // 9. Successfully finished - delete backup
      await VaultDescriptor.deleteBackup(_paths);

    } catch (e) {
      // If we failed before updating vault.json, the next unlock 
      // will still use the old salt/password. 
      // The database might be in an inconsistent state if rekey succeeded 
      // but descriptor update failed. This is what the recovery in unlock handles.
      rethrow;
    }
  }
}
