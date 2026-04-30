import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:sqflite_sqlcipher/sqflite.dart';

import '../../core/crypto/aead.dart';
import '../vault/vault_service.dart';

class HiddenTagRepository {
  HiddenTagRepository(this._vault);

  final VaultService _vault;
  final StreamController<void> _changes = StreamController.broadcast();

  Stream<void> get changes => _changes.stream;

  Database get _db => _vault.db;

  Future<void> assignByName(int documentId, String name) async {
    final hash = await _vault.tagHmac.hash(name);
    final sealed = await Aead.seal(
      key: _vault.kek,
      plaintext: utf8.encode(name.trim()),
    );
    await _db.insert(
      'hidden_tag_index',
      {
        'tag_hash': hash,
        'document_id': documentId,
        'encrypted_name': sealed.ciphertext,
        'encrypted_name_nonce': sealed.nonce,
        'encrypted_name_mac': sealed.mac,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    _notify();
  }

  Future<void> removeByName(int documentId, String name) async {
    final hash = await _vault.tagHmac.hash(name);
    await _db.delete(
      'hidden_tag_index',
      where: 'document_id = ? AND tag_hash = ?',
      whereArgs: [documentId, hash],
    );
    _notify();
  }

  Future<void> removeByHash(int documentId, Uint8List tagHash) async {
    await _db.delete(
      'hidden_tag_index',
      where: 'document_id = ? AND tag_hash = ?',
      whereArgs: [documentId, tagHash],
    );
    _notify();
  }

  Future<List<String>> namesForDocument(int documentId) async {
    final rows = await _db.query(
      'hidden_tag_index',
      where: 'document_id = ?',
      whereArgs: [documentId],
    );
    final out = <String>[];
    for (final r in rows) {
      final ct = r['encrypted_name'];
      final nonce = r['encrypted_name_nonce'];
      final mac = r['encrypted_name_mac'];
      if (ct == null || nonce == null || mac == null) continue;
      try {
        final plaintext = await Aead.open(
          key: _vault.kek,
          sealed: SealedBytes(
            nonce: nonce as Uint8List,
            ciphertext: ct as Uint8List,
            mac: mac as Uint8List,
          ),
        );
        out.add(utf8.decode(plaintext));
      } catch (_) {}
    }
    out.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return out;
  }

  Future<List<int>> findDocumentsByName(String name) async {
    if (name.trim().isEmpty) return const [];
    final hash = await _vault.tagHmac.hash(name);
    final rows = await _db.query(
      'hidden_tag_index',
      columns: ['document_id'],
      where: 'tag_hash = ?',
      whereArgs: [hash],
    );
    return rows.map((r) => r['document_id']! as int).toList();
  }

  void _notify() {
    if (!_changes.isClosed) _changes.add(null);
  }

  void dispose() {
    _changes.close();
  }
}
