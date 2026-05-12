import 'dart:async';

import 'package:sqflite_sqlcipher/sqflite.dart';

import '../vault/vault_service.dart';
import 'folder.dart';

class FolderRepository {
  FolderRepository(this._vault);

  final VaultService _vault;
  final StreamController<void> _changes = StreamController.broadcast();

  Stream<void> get changes => _changes.stream;

  Database get _db => _vault.db;

  Future<List<Folder>> listAll() async {
    final rows = await _db.rawQuery('''
      SELECT f.*, (
        (SELECT COUNT(*) FROM documents d WHERE d.folder_id = f.id) +
        (SELECT COUNT(*) FROM notes n WHERE n.folder_id = f.id)
      ) AS document_count
      FROM folders f
      ORDER BY f.name COLLATE NOCASE
    ''');
    return rows.map(Folder.fromRow).toList();
  }

  Future<int> countWithoutFolder() async {
    final rows = await _db.rawQuery(
      'SELECT COUNT(*) AS c FROM documents WHERE folder_id IS NULL',
    );
    return rows.first['c'] as int? ?? 0;
  }

  Future<Folder?> getById(int id) async {
    final rows = await _db.query('folders', where: 'id = ?', whereArgs: [id], limit: 1);
    if (rows.isEmpty) return null;
    return Folder.fromRow(rows.first);
  }

  Future<Folder> create(String name, {String? color}) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) {
      throw ArgumentError('Folder name cannot be empty');
    }
    final existing = await _db.query(
      'folders',
      where: 'LOWER(name) = LOWER(?)',
      whereArgs: [trimmed],
      limit: 1,
    );
    if (existing.isNotEmpty) {
      return Folder.fromRow(existing.first);
    }
    final id = await _db.insert('folders', {
      'name': trimmed,
      'color': color,
      'created_at': DateTime.now().millisecondsSinceEpoch,
    });
    _notify();
    return Folder(
      id: id,
      name: trimmed,
      color: color,
      createdAt: DateTime.now(),
    );
  }

  Future<void> rename(int id, String newName) async {
    final trimmed = newName.trim();
    if (trimmed.isEmpty) {
      throw ArgumentError('Folder name cannot be empty');
    }
    await _db.update(
      'folders',
      {'name': trimmed},
      where: 'id = ?',
      whereArgs: [id],
    );
    _notify();
  }

  Future<void> delete(int id) async {
    await _db.delete('folders', where: 'id = ?', whereArgs: [id]);
    _notify();
  }

  Future<void> assignDocument(int documentId, int? folderId) async {
    await _db.update(
      'documents',
      {
        'folder_id': folderId,
        'updated_at': DateTime.now().millisecondsSinceEpoch,
      },
      where: 'id = ?',
      whereArgs: [documentId],
    );
    _notify();
  }

  Future<void> assignNote(int noteId, int? folderId) async {
    await _db.update(
      'notes',
      {
        'folder_id': folderId,
        'updated_at': DateTime.now().millisecondsSinceEpoch,
      },
      where: 'id = ?',
      whereArgs: [noteId],
    );
    _notify();
  }

  void _notify() {
    if (!_changes.isClosed) _changes.add(null);
  }

  void dispose() {
    _changes.close();
  }
}
