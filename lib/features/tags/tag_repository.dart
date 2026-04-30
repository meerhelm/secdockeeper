import 'dart:async';

import 'package:sqflite_sqlcipher/sqflite.dart';

import '../vault/vault_service.dart';
import 'tag.dart';

class TagRepository {
  TagRepository(this._vault);

  final VaultService _vault;
  final StreamController<void> _changes = StreamController.broadcast();

  Stream<void> get changes => _changes.stream;

  Database get _db => _vault.db;

  Future<List<Tag>> listAll() async {
    final rows = await _db.query('tags', orderBy: 'name COLLATE NOCASE');
    return rows.map(Tag.fromRow).toList();
  }

  Future<List<int>> findDocumentsByQuery(String query) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return const [];
    final escaped = trimmed.replaceAll(r'\', r'\\').replaceAll('%', r'\%').replaceAll('_', r'\_');
    final rows = await _db.rawQuery('''
      SELECT DISTINCT dt.document_id FROM tags t
      JOIN document_tags dt ON dt.tag_id = t.id
      WHERE LOWER(t.name) LIKE ? ESCAPE '\\'
    ''', ['%${escaped.toLowerCase()}%']);
    return rows.map((r) => r['document_id']! as int).toList();
  }

  Future<List<Tag>> forDocument(int documentId) async {
    final rows = await _db.rawQuery('''
      SELECT t.* FROM tags t
      JOIN document_tags dt ON dt.tag_id = t.id
      WHERE dt.document_id = ?
      ORDER BY t.name COLLATE NOCASE
    ''', [documentId]);
    return rows.map(Tag.fromRow).toList();
  }

  Future<Tag> upsert(String name, {String? color}) async {
    final normalized = name.trim();
    if (normalized.isEmpty) {
      throw ArgumentError('Tag name cannot be empty');
    }
    final existing = await _db.query(
      'tags',
      where: 'LOWER(name) = LOWER(?)',
      whereArgs: [normalized],
      limit: 1,
    );
    if (existing.isNotEmpty) {
      return Tag.fromRow(existing.first);
    }
    final id = await _db.insert('tags', {
      'name': normalized,
      'color': color,
      'created_at': DateTime.now().millisecondsSinceEpoch,
    });
    _notify();
    return Tag(
      id: id,
      name: normalized,
      color: color,
      createdAt: DateTime.now(),
    );
  }

  Future<void> assign(int documentId, int tagId) async {
    await _db.insert(
      'document_tags',
      {'document_id': documentId, 'tag_id': tagId},
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
    _notify();
  }

  Future<void> unassign(int documentId, int tagId) async {
    await _db.delete(
      'document_tags',
      where: 'document_id = ? AND tag_id = ?',
      whereArgs: [documentId, tagId],
    );
    _notify();
  }

  Future<void> delete(int id) async {
    await _db.delete('tags', where: 'id = ?', whereArgs: [id]);
    _notify();
  }

  void _notify() {
    if (!_changes.isClosed) _changes.add(null);
  }

  void dispose() {
    _changes.close();
  }
}
