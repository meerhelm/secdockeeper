import 'dart:async';
import 'dart:typed_data';

import 'package:sqflite_sqlcipher/sqflite.dart';

import '../vault/vault_service.dart';
import 'document.dart';

class DocumentRepository {
  DocumentRepository(this._vault);

  final VaultService _vault;
  final StreamController<void> _changes = StreamController.broadcast();

  Stream<void> get changes => _changes.stream;

  Database get _db => _vault.db;

  Future<int> create({
    required String uuid,
    required String originalName,
    String? mimeType,
    required int size,
    required Uint8List dekWrapped,
    required Uint8List dekNonce,
    required Uint8List dekMac,
    required Uint8List fileNonce,
    required Uint8List fileMac,
    String? ocrText,
    String? classificationAuto,
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final id = await _db.insert('documents', {
      'uuid': uuid,
      'original_name': originalName,
      'mime_type': mimeType,
      'size': size,
      'dek_wrapped': dekWrapped,
      'dek_nonce': dekNonce,
      'dek_mac': dekMac,
      'file_nonce': fileNonce,
      'file_mac': fileMac,
      'ocr_text': ocrText,
      'classification_auto': classificationAuto,
      'created_at': now,
      'updated_at': now,
    });
    await _db.insert('documents_fts', {
      'rowid': id,
      'ocr_text': ocrText ?? '',
      'original_name': originalName,
    });
    _notify();
    return id;
  }

  Future<List<Document>> list({
    String? query,
    List<int>? tagIds,
    List<int>? hiddenDocIds,
    int? folderId,
    bool onlyUnassignedFolder = false,
  }) async {
    final hasFts = query != null && query.trim().isNotEmpty;
    final hasTagFilter = tagIds != null && tagIds.isNotEmpty;
    final hasHiddenFilter = hiddenDocIds != null;

    final where = <String>[];
    final args = <Object?>[];
    var sql = '''
      SELECT d.* FROM documents d
    ''';
    if (hasFts) {
      sql += '''
        JOIN documents_fts f ON f.rowid = d.id
      ''';
      where.add('documents_fts MATCH ?');
      args.add(_buildFtsQuery(query));
    }
    if (hasTagFilter) {
      final placeholders = List.filled(tagIds.length, '?').join(',');
      sql += '''
        JOIN document_tags dt ON dt.document_id = d.id
      ''';
      where.add('dt.tag_id IN ($placeholders)');
      args.addAll(tagIds);
    }
    if (hasHiddenFilter) {
      if (hiddenDocIds.isEmpty) {
        return const [];
      }
      final placeholders = List.filled(hiddenDocIds.length, '?').join(',');
      where.add('d.id IN ($placeholders)');
      args.addAll(hiddenDocIds);
    }
    if (onlyUnassignedFolder) {
      where.add('d.folder_id IS NULL');
    } else if (folderId != null) {
      where.add('d.folder_id = ?');
      args.add(folderId);
    }

    if (where.isNotEmpty) {
      sql += ' WHERE ${where.join(' AND ')}';
    }
    if (hasTagFilter) {
      sql += ' GROUP BY d.id HAVING COUNT(DISTINCT dt.tag_id) = ${tagIds.length}';
    }
    sql += ' ORDER BY d.created_at DESC';

    final rows = await _db.rawQuery(sql, args);
    return rows.map(Document.fromRow).toList();
  }

  Future<Document?> getById(int id) async {
    final rows = await _db.query('documents', where: 'id = ?', whereArgs: [id], limit: 1);
    if (rows.isEmpty) return null;
    return Document.fromRow(rows.first);
  }

  Future<DocumentCryptoMaterial?> getCryptoFor(int id) async {
    final rows = await _db.query(
      'documents',
      columns: ['dek_wrapped', 'dek_nonce', 'dek_mac', 'file_nonce', 'file_mac'],
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    final r = rows.first;
    return DocumentCryptoMaterial(
      dekWrapped: r['dek_wrapped']! as Uint8List,
      dekNonce: r['dek_nonce']! as Uint8List,
      dekMac: r['dek_mac']! as Uint8List,
      fileNonce: r['file_nonce']! as Uint8List,
      fileMac: r['file_mac']! as Uint8List,
    );
  }

  Future<Map<int, DocumentCryptoMaterial>> getAllCrypto() async {
    final rows = await _db.query(
      'documents',
      columns: ['id', 'dek_wrapped', 'dek_nonce', 'dek_mac', 'file_nonce', 'file_mac'],
    );
    return {
      for (final r in rows)
        r['id']! as int: DocumentCryptoMaterial(
          dekWrapped: r['dek_wrapped']! as Uint8List,
          dekNonce: r['dek_nonce']! as Uint8List,
          dekMac: r['dek_mac']! as Uint8List,
          fileNonce: r['file_nonce']! as Uint8List,
          fileMac: r['file_mac']! as Uint8List,
        ),
    };
  }

  Future<void> updateWrappedDek(int id, Uint8List wrapped, Uint8List nonce, Uint8List mac) async {
    await _db.update(
      'documents',
      {
        'dek_wrapped': wrapped,
        'dek_nonce': nonce,
        'dek_mac': mac,
        'updated_at': DateTime.now().millisecondsSinceEpoch,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> deleteById(int id) async {
    await _db.transaction((txn) async {
      await txn.delete('documents', where: 'id = ?', whereArgs: [id]);
      await txn.delete('documents_fts', where: 'rowid = ?', whereArgs: [id]);
    });
    _notify();
  }

  Future<void> rename(int id, String newName) async {
    final trimmed = newName.trim();
    if (trimmed.isEmpty) {
      throw ArgumentError('Document name cannot be empty');
    }
    await _db.transaction((txn) async {
      await txn.update(
        'documents',
        {
          'original_name': trimmed,
          'updated_at': DateTime.now().millisecondsSinceEpoch,
        },
        where: 'id = ?',
        whereArgs: [id],
      );
      final row = (await txn.query(
        'documents',
        columns: ['ocr_text'],
        where: 'id = ?',
        whereArgs: [id],
        limit: 1,
      )).first;
      await txn.delete('documents_fts', where: 'rowid = ?', whereArgs: [id]);
      await txn.insert('documents_fts', {
        'rowid': id,
        'ocr_text': row['ocr_text'] ?? '',
        'original_name': trimmed,
      });
    });
    _notify();
  }

  Future<void> updateClassificationManual(int id, String? value) async {
    await _db.update(
      'documents',
      {
        'classification_manual': value,
        'updated_at': DateTime.now().millisecondsSinceEpoch,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
    _notify();
  }

  Future<void> updateOcrText(int id, String text, String? autoClass) async {
    await _db.transaction((txn) async {
      await txn.update(
        'documents',
        {
          'ocr_text': text,
          'classification_auto': autoClass,
          'updated_at': DateTime.now().millisecondsSinceEpoch,
        },
        where: 'id = ?',
        whereArgs: [id],
      );
      await txn.delete('documents_fts', where: 'rowid = ?', whereArgs: [id]);
      final row = (await txn.query(
        'documents',
        columns: ['original_name'],
        where: 'id = ?',
        whereArgs: [id],
        limit: 1,
      )).first;
      await txn.insert('documents_fts', {
        'rowid': id,
        'ocr_text': text,
        'original_name': row['original_name'],
      });
    });
    _notify();
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
