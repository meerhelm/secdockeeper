import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:sqflite_sqlcipher/sqflite.dart';
import 'package:uuid/uuid.dart';

import '../../core/crypto/aead.dart';
import '../../core/crypto/vault_crypto.dart';
import '../vault/vault_service.dart';
import 'note.dart';

class NoteRepository {
  NoteRepository(this._vault);

  final VaultService _vault;
  final StreamController<void> _changes = StreamController.broadcast();
  static const _uuid = Uuid();

  Stream<void> get changes => _changes.stream;

  Database get _db => _vault.db;

  Future<Note> create({String title = '', String body = ''}) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final uuid = _uuid.v4();
    final crypto = _vault.crypto;
    final dek = await crypto.generateDek();
    final wrapped = await crypto.wrapDek(kek: _vault.kek, dek: dek);
    final sealed = await crypto.encryptBlob(
      dek: dek,
      plaintext: utf8.encode(body),
    );
    final id = await _db.transaction((txn) async {
      final id = await txn.insert('notes', {
        'uuid': uuid,
        'title': title,
        'dek_wrapped': wrapped.ciphertext,
        'dek_nonce': wrapped.nonce,
        'dek_mac': wrapped.mac,
        'body_ciphertext': sealed.ciphertext,
        'body_nonce': sealed.nonce,
        'body_mac': sealed.mac,
        'created_at': now,
        'updated_at': now,
      });
      await txn.insert('notes_fts', {
        'rowid': id,
        'title': title,
      });
      return id;
    });
    _notify();
    return Note(
      id: id,
      uuid: uuid,
      title: title,
      body: body,
      createdAt: DateTime.fromMillisecondsSinceEpoch(now),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(now),
    );
  }

  Future<List<Note>> list({
    String? query,
    int? folderId,
    bool onlyUnassignedFolder = false,
  }) async {
    final hasFts = query != null && query.trim().isNotEmpty;
    final where = <String>[];
    final args = <Object?>[];

    var sql = 'SELECT n.* FROM notes n';
    if (hasFts) {
      sql += ' JOIN notes_fts f ON f.rowid = n.id';
      where.add('notes_fts MATCH ?');
      args.add(_buildFtsQuery(query));
    }
    if (onlyUnassignedFolder) {
      where.add('n.folder_id IS NULL');
    } else if (folderId != null) {
      where.add('n.folder_id = ?');
      args.add(folderId);
    }
    if (where.isNotEmpty) {
      sql += ' WHERE ${where.join(' AND ')}';
    }
    sql += ' ORDER BY n.updated_at DESC';

    final rows = await _db.rawQuery(sql, args);
    final notes = <Note>[];
    for (final row in rows) {
      notes.add(await _hydrate(row));
    }
    return notes;
  }

  Future<Note?> getById(int id) async {
    final rows =
        await _db.query('notes', where: 'id = ?', whereArgs: [id], limit: 1);
    if (rows.isEmpty) return null;
    return _hydrate(rows.first);
  }

  Future<void> update({
    required int id,
    required String title,
    required String body,
  }) async {
    final material = await _getCryptoFor(id);
    if (material == null) return;
    final crypto = _vault.crypto;
    final dek = await crypto.unwrapDek(
      kek: _vault.kek,
      wrapped: WrappedDek(
        nonce: material.dekNonce,
        ciphertext: material.dekWrapped,
        mac: material.dekMac,
      ),
    );
    final sealed = await crypto.encryptBlob(
      dek: dek,
      plaintext: utf8.encode(body),
    );
    final now = DateTime.now().millisecondsSinceEpoch;
    await _db.transaction((txn) async {
      final updated = await txn.update(
        'notes',
        {
          'title': title,
          'body_ciphertext': sealed.ciphertext,
          'body_nonce': sealed.nonce,
          'body_mac': sealed.mac,
          'updated_at': now,
        },
        where: 'id = ?',
        whereArgs: [id],
      );
      if (updated == 0) return;
      await txn.delete('notes_fts', where: 'rowid = ?', whereArgs: [id]);
      await txn.insert('notes_fts', {
        'rowid': id,
        'title': title,
      });
    });
    _notify();
  }

  Future<void> deleteById(int id) async {
    await _db.transaction((txn) async {
      await txn.delete('notes', where: 'id = ?', whereArgs: [id]);
      await txn.delete('notes_fts', where: 'rowid = ?', whereArgs: [id]);
    });
    _notify();
  }

  Future<Map<int, NoteCryptoMaterial>> getAllCrypto() async {
    final rows = await _db.query(
      'notes',
      columns: [
        'id',
        'dek_wrapped',
        'dek_nonce',
        'dek_mac',
        'body_ciphertext',
        'body_nonce',
        'body_mac',
      ],
    );
    return {
      for (final r in rows)
        r['id']! as int: NoteCryptoMaterial(
          dekWrapped: r['dek_wrapped']! as Uint8List,
          dekNonce: r['dek_nonce']! as Uint8List,
          dekMac: r['dek_mac']! as Uint8List,
          bodyCiphertext: r['body_ciphertext']! as Uint8List,
          bodyNonce: r['body_nonce']! as Uint8List,
          bodyMac: r['body_mac']! as Uint8List,
        ),
    };
  }

  Future<NoteCryptoMaterial?> _getCryptoFor(int id) async {
    final rows = await _db.query(
      'notes',
      columns: [
        'dek_wrapped',
        'dek_nonce',
        'dek_mac',
        'body_ciphertext',
        'body_nonce',
        'body_mac',
      ],
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    final r = rows.first;
    return NoteCryptoMaterial(
      dekWrapped: r['dek_wrapped']! as Uint8List,
      dekNonce: r['dek_nonce']! as Uint8List,
      dekMac: r['dek_mac']! as Uint8List,
      bodyCiphertext: r['body_ciphertext']! as Uint8List,
      bodyNonce: r['body_nonce']! as Uint8List,
      bodyMac: r['body_mac']! as Uint8List,
    );
  }

  Future<Note> _hydrate(Map<String, Object?> row) async {
    final crypto = _vault.crypto;
    final dek = await crypto.unwrapDek(
      kek: _vault.kek,
      wrapped: WrappedDek(
        nonce: row['dek_nonce']! as Uint8List,
        ciphertext: row['dek_wrapped']! as Uint8List,
        mac: row['dek_mac']! as Uint8List,
      ),
    );
    final plaintext = await crypto.decryptBlob(
      dek: dek,
      sealed: SealedBytes(
        nonce: row['body_nonce']! as Uint8List,
        ciphertext: row['body_ciphertext']! as Uint8List,
        mac: row['body_mac']! as Uint8List,
      ),
    );
    return Note(
      id: row['id']! as int,
      uuid: row['uuid']! as String,
      title: (row['title'] as String?) ?? '',
      body: utf8.decode(plaintext),
      createdAt:
          DateTime.fromMillisecondsSinceEpoch(row['created_at']! as int),
      updatedAt:
          DateTime.fromMillisecondsSinceEpoch(row['updated_at']! as int),
      folderId: row['folder_id'] as int?,
    );
  }

  String _buildFtsQuery(String raw) {
    final terms = raw
        .trim()
        .split(RegExp(r'\s+'))
        .where((t) => t.isNotEmpty)
        .map((t) => '"${t.replaceAll('"', '""')}"*');
    return terms.join(' AND ');
  }

  void _notify() {
    if (!_changes.isClosed) _changes.add(null);
  }

  void dispose() {
    _changes.close();
  }
}
