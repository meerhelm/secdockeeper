import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:sqflite_sqlcipher/sqflite.dart';
import 'package:uuid/uuid.dart';

import '../../core/crypto/aead.dart';
import '../../core/crypto/vault_crypto.dart';
import '../../core/logging/app_logger.dart';
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
    final formatVersion = _vault.rowFormatVersion;
    final aad = rowAad(formatVersion: formatVersion, uuid: uuid);
    final dek = await crypto.generateDek();
    final wrapped = await crypto.wrapDek(kek: _vault.wrapKey, dek: dek, aad: aad);
    final sealed = await crypto.encryptBlob(
      dek: dek,
      plaintext: utf8.encode(body),
      aad: aad,
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
        'format_version': formatVersion,
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
      try {
        notes.add(await _hydrate(row));
      } catch (e, st) {
        log.e('[note_repo] _hydrate failed for row id=${row['id']}',
            error: e, stackTrace: st);
      }
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
    final aad = rowAad(
      formatVersion: material.formatVersion,
      uuid: material.uuid,
    );
    final dek = await crypto.unwrapDek(
      kek: _vault.wrapKey,
      wrapped: WrappedDek(
        nonce: material.dekNonce,
        ciphertext: material.dekWrapped,
        mac: material.dekMac,
      ),
      aad: aad,
    );
    final sealed = await crypto.encryptBlob(
      dek: dek,
      plaintext: utf8.encode(body),
      aad: aad,
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
        'uuid',
        'dek_wrapped',
        'dek_nonce',
        'dek_mac',
        'body_ciphertext',
        'body_nonce',
        'body_mac',
        'format_version',
      ],
    );
    return {
      for (final r in rows)
        r['id']! as int: NoteCryptoMaterial(
          uuid: r['uuid']! as String,
          dekWrapped: r['dek_wrapped']! as Uint8List,
          dekNonce: r['dek_nonce']! as Uint8List,
          dekMac: r['dek_mac']! as Uint8List,
          bodyCiphertext: (r['body_ciphertext'] as Uint8List?) ?? Uint8List(0),
          bodyNonce: r['body_nonce']! as Uint8List,
          bodyMac: r['body_mac']! as Uint8List,
          formatVersion: (r['format_version'] as int?) ?? 1,
        ),
    };
  }

  Future<NoteCryptoMaterial?> _getCryptoFor(int id) async {
    final rows = await _db.query(
      'notes',
      columns: [
        'uuid',
        'dek_wrapped',
        'dek_nonce',
        'dek_mac',
        'body_ciphertext',
        'body_nonce',
        'body_mac',
        'format_version',
      ],
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    final r = rows.first;
    return NoteCryptoMaterial(
      uuid: r['uuid']! as String,
      dekWrapped: r['dek_wrapped']! as Uint8List,
      dekNonce: r['dek_nonce']! as Uint8List,
      dekMac: r['dek_mac']! as Uint8List,
      bodyCiphertext: (r['body_ciphertext'] as Uint8List?) ?? Uint8List(0),
      bodyNonce: r['body_nonce']! as Uint8List,
      bodyMac: r['body_mac']! as Uint8List,
      formatVersion: (r['format_version'] as int?) ?? 1,
    );
  }

  Future<Note> _hydrate(Map<String, Object?> row) async {
    final crypto = _vault.crypto;
    final uuid = row['uuid']! as String;
    final aad = rowAad(
      formatVersion: (row['format_version'] as int?) ?? 1,
      uuid: uuid,
    );
    final dek = await crypto.unwrapDek(
      kek: _vault.wrapKey,
      wrapped: WrappedDek(
        nonce: row['dek_nonce']! as Uint8List,
        ciphertext: row['dek_wrapped']! as Uint8List,
        mac: row['dek_mac']! as Uint8List,
      ),
      aad: aad,
    );
    // sqflite returns empty BLOBs as `null` in the column map, so we can't use
    // `!` here — an empty body (the default for a freshly created note)
    // legitimately encrypts to an empty ciphertext.
    final plaintext = await crypto.decryptBlob(
      dek: dek,
      sealed: SealedBytes(
        nonce: row['body_nonce']! as Uint8List,
        ciphertext: (row['body_ciphertext'] as Uint8List?) ?? Uint8List(0),
        mac: row['body_mac']! as Uint8List,
      ),
      aad: aad,
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
