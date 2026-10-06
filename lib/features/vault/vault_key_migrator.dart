import 'dart:convert';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:sqflite_sqlcipher/sqflite.dart';

import '../../core/crypto/aead.dart';
import '../../core/crypto/tag_hmac.dart';
import '../../core/crypto/vault_crypto.dart';
import '../../core/logging/app_logger.dart';
import '../../core/storage/vault_database.dart';

/// Moves a vault from one KEK to another in steps that are each safe to
/// repeat. Every row is unwrapped with whichever of the two keys works and
/// re-wrapped under [target], so a run interrupted at any point can be
/// finished (or reversed) by running it again with the keys swapped.
class VaultKeyMigrator {
  VaultKeyMigrator({
    required this.target,
    required this.other,
    VaultCrypto? crypto,
  }) : _crypto = crypto ?? VaultCrypto();

  final SecretKey target;
  final SecretKey other;
  final VaultCrypto _crypto;

  /// Opens the SQLCipher DB under [target], rekeying it from [other] if the
  /// previous run stopped before (or after) `PRAGMA rekey`.
  Future<VaultDatabase> open(String path) async {
    final targetPassword = await kekToDbPassword(target);
    try {
      return await VaultDatabase.open(path: path, password: targetPassword);
    } catch (e, st) {
      log.d('[key_migrator] DB not under target key yet; trying the other',
          error: e, stackTrace: st);
    }
    final db = await VaultDatabase.open(
      path: path,
      password: await kekToDbPassword(other),
    );
    try {
      await db.rekey(targetPassword);
    } catch (_) {
      await db.close();
      rethrow;
    }
    return db;
  }

  /// Re-wraps every DEK and hidden-tag entry under [target] in a single
  /// transaction. Rows already under [target] are left as they are.
  Future<void> rewrapAll(Database db) async {
    final targetTagHmac = TagHmac(await deriveTagHmacKey(target));
    await db.transaction((txn) async {
      for (final table in const ['documents', 'notes']) {
        final rows = await txn.query(
          table,
          columns: ['id', 'dek_wrapped', 'dek_nonce', 'dek_mac'],
        );
        for (final r in rows) {
          final wrapped = WrappedDek(
            nonce: r['dek_nonce']! as Uint8List,
            ciphertext: r['dek_wrapped']! as Uint8List,
            mac: r['dek_mac']! as Uint8List,
          );
          if (await _opensWith(target, wrapped)) continue;
          final dek = await _crypto.unwrapDek(kek: other, wrapped: wrapped);
          final rewrapped = await _crypto.wrapDek(kek: target, dek: dek);
          await txn.update(
            table,
            {
              'dek_wrapped': rewrapped.ciphertext,
              'dek_nonce': rewrapped.nonce,
              'dek_mac': rewrapped.mac,
            },
            where: 'id = ?',
            whereArgs: [r['id']],
          );
        }
      }

      final tagRows = await txn.query('hidden_tag_index');
      for (final r in tagRows) {
        final ct = r['encrypted_name'] as Uint8List?;
        final nonce = r['encrypted_name_nonce'] as Uint8List?;
        final mac = r['encrypted_name_mac'] as Uint8List?;
        if (ct == null || nonce == null || mac == null) {
          // Without the name the hash can't be recomputed under a new key.
          log.w('[key_migrator] hidden tag entry without encrypted name skipped');
          continue;
        }
        final sealed = SealedBytes(nonce: nonce, ciphertext: ct, mac: mac);
        final oldHash = r['tag_hash']! as Uint8List;
        final documentId = r['document_id']! as int;

        var nameBytes = await _tryOpen(target, sealed);
        final alreadyTarget = nameBytes != null;
        nameBytes ??= await Aead.open(key: other, sealed: sealed);
        final newHash = await targetTagHmac.hash(utf8.decode(nameBytes));
        if (alreadyTarget && _bytesEqual(oldHash, newHash)) continue;

        final resealed = alreadyTarget
            ? sealed
            : await Aead.seal(key: target, plaintext: nameBytes);
        await txn.delete(
          'hidden_tag_index',
          where: 'document_id = ? AND tag_hash = ?',
          whereArgs: [documentId, oldHash],
        );
        await txn.insert(
          'hidden_tag_index',
          {
            'tag_hash': newHash,
            'document_id': documentId,
            'encrypted_name': resealed.ciphertext,
            'encrypted_name_nonce': resealed.nonce,
            'encrypted_name_mac': resealed.mac,
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
    });
  }

  Future<bool> _opensWith(SecretKey kek, WrappedDek wrapped) async {
    try {
      await _crypto.unwrapDek(kek: kek, wrapped: wrapped);
      return true;
    } on SecretBoxAuthenticationError {
      return false;
    }
  }

  static Future<Uint8List?> _tryOpen(SecretKey key, SealedBytes sealed) async {
    try {
      return await Aead.open(key: key, sealed: sealed);
    } on SecretBoxAuthenticationError {
      return null;
    }
  }

  static bool _bytesEqual(List<int> a, List<int> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}
