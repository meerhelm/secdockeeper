import 'package:sqflite_sqlcipher/sqflite.dart';

import '../logging/app_logger.dart';

class VaultDatabase {
  VaultDatabase._(this._db);

  final Database _db;

  Database get db => _db;

  static VaultDatabase fromRaw(Database db) => VaultDatabase._(db);

  static Future<VaultDatabase> open({
    required String path,
    required String password,
  }) async {
    final database = await openDatabase(
      path,
      version: 4,
      password: password,
      onConfigure: (db) async {
        await db.execute('PRAGMA foreign_keys = ON;');
      },
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );

    // Ensure the notes storage exists, in case a restored backup bypassed
    // migrations (e.g. user_version was already at the target before the
    // schema was actually applied, or a prior migration failed partway).
    await _ensureNotesStorage(database);

    return VaultDatabase._(database);
  }

  static Future<bool> _tableExists(Database db, String name) async {
    final rows = await db.rawQuery(
      "SELECT name FROM sqlite_master WHERE type='table' AND name=?;",
      [name],
    );
    return rows.isNotEmpty;
  }

  static Future<Set<String>> _columnsOf(Database db, String table) async {
    final rows = await db.rawQuery('PRAGMA table_info($table);');
    return {for (final r in rows) r['name']! as String};
  }

  /// Columns that the current Dart code expects on the `notes` table. If any
  /// are missing, the table was created by an older build with an incompatible
  /// schema — there's no usable data to migrate (the per-row crypto material
  /// is gone), so we drop and recreate.
  static const _notesRequiredColumns = {
    'id',
    'uuid',
    'title',
    'dek_wrapped',
    'dek_nonce',
    'dek_mac',
    'body_ciphertext',
    'body_nonce',
    'body_mac',
    'folder_id',
    'created_at',
    'updated_at',
  };

  // Single source of truth for the notes storage DDL, shared by _onCreate,
  // _onUpgrade and the _ensureNotesStorage repair path so the three can never
  // drift apart.
  static const _createNotesTableSql = '''
    CREATE TABLE notes (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      uuid TEXT NOT NULL UNIQUE,
      title TEXT NOT NULL DEFAULT '',
      dek_wrapped BLOB NOT NULL,
      dek_nonce BLOB NOT NULL,
      dek_mac BLOB NOT NULL,
      body_ciphertext BLOB NOT NULL,
      body_nonce BLOB NOT NULL,
      body_mac BLOB NOT NULL,
      folder_id INTEGER REFERENCES folders(id) ON DELETE SET NULL,
      created_at INTEGER NOT NULL,
      updated_at INTEGER NOT NULL
    );
  ''';
  static const _createNotesFtsSql =
      'CREATE VIRTUAL TABLE notes_fts USING fts5(title);';
  static const _createNotesIndexesSql = [
    'CREATE INDEX IF NOT EXISTS idx_notes_updated_at ON notes(updated_at);',
    'CREATE INDEX IF NOT EXISTS idx_notes_folder ON notes(folder_id);',
  ];

  /// `vault_meta` key set when [_ensureNotesStorage] is forced to drop an
  /// incompatible `notes` table. Read and cleared by [consumeNotesResetMarker]
  /// so the UI can tell the user their notes could not be migrated, rather than
  /// the loss being silent.
  static const notesResetMetaKey = 'notes_table_reset_at';

  /// Returns the timestamp (ms since epoch) of the most recent destructive
  /// notes-table reset, if one happened since it was last consumed, then clears
  /// it. Null when there is nothing to report.
  Future<int?> consumeNotesResetMarker() async {
    final rows = await _db.query('vault_meta',
        where: 'key = ?', whereArgs: [notesResetMetaKey], limit: 1);
    if (rows.isEmpty) return null;
    await _db.delete('vault_meta', where: 'key = ?', whereArgs: [notesResetMetaKey]);
    return int.tryParse(rows.first['value']! as String);
  }

  static Future<void> _ensureNotesStorage(Database db) async {
    final hasNotes = await _tableExists(db, 'notes');
    var needsCreate = !hasNotes;
    var wasDestructiveReset = false;

    if (hasNotes) {
      final existing = await _columnsOf(db, 'notes');
      final missing = _notesRequiredColumns.difference(existing);
      if (missing.isNotEmpty) {
        // The per-row crypto material in the incompatible table is unusable, so
        // there is nothing to migrate — but record the loss so it can surface.
        log.e('[vault_db] notes table schema drift; dropping and recreating. '
            'missing columns: $missing existing columns: $existing');
        await db.execute('DROP TABLE IF EXISTS notes_fts;');
        await db.execute('DROP TABLE IF EXISTS notes;');
        needsCreate = true;
        wasDestructiveReset = true;
      }
    }

    if (needsCreate) {
      await db.execute(_createNotesTableSql);
      for (final sql in _createNotesIndexesSql) {
        await db.execute(sql);
      }
    }

    final hasFts = await _tableExists(db, 'notes_fts');
    if (!hasFts) {
      await db.execute(_createNotesFtsSql);
      // Rebuild the FTS index from any rows that may already exist.
      await db.execute(
        'INSERT INTO notes_fts(rowid, title) SELECT id, COALESCE(title, "") FROM notes;',
      );
    }

    if (wasDestructiveReset && await _tableExists(db, 'vault_meta')) {
      await db.insert(
        'vault_meta',
        {
          'key': notesResetMetaKey,
          'value': DateTime.now().millisecondsSinceEpoch.toString(),
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
  }

  Future<void> close() => _db.close();

  // PRAGMA cannot take a bound parameter, so the passphrase is interpolated.
  // Every passphrase this app produces is base64 (a base64-encoded key), which
  // contains no quote characters — assert that invariant so a future change to
  // the passphrase format can never silently open a SQL-injection / corruption
  // hole here.
  static final _base64 = RegExp(r'^[A-Za-z0-9+/]+={0,2}$');

  Future<void> rekey(String newPassword) async {
    if (!_base64.hasMatch(newPassword)) {
      throw ArgumentError('rekey passphrase must be base64');
    }
    // Using rawQuery instead of execute to ensure it's processed and awaited
    // correctly by sqflite_sqlcipher. PRAGMA rekey returns an empty list on success.
    await _db.rawQuery("PRAGMA rekey = '$newPassword'");
  }

  static Future<void> _onCreate(Database db, int version) async {
    final batch = db.batch();
    batch.execute('''
      CREATE TABLE documents (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        uuid TEXT NOT NULL UNIQUE,
        original_name TEXT NOT NULL,
        mime_type TEXT,
        size INTEGER NOT NULL,
        dek_wrapped BLOB NOT NULL,
        dek_nonce BLOB NOT NULL,
        dek_mac BLOB NOT NULL,
        file_nonce BLOB NOT NULL,
        file_mac BLOB NOT NULL,
        ocr_text TEXT,
        classification_auto TEXT,
        classification_manual TEXT,
        folder_id INTEGER REFERENCES folders(id) ON DELETE SET NULL,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL
      );
    ''');
    batch.execute('CREATE INDEX idx_documents_created_at ON documents(created_at);');
    batch.execute('CREATE INDEX idx_documents_folder ON documents(folder_id);');

    batch.execute('''
      CREATE TABLE folders (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL UNIQUE,
        color TEXT,
        created_at INTEGER NOT NULL
      );
    ''');

    batch.execute('''
      CREATE TABLE tags (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL UNIQUE,
        color TEXT,
        created_at INTEGER NOT NULL
      );
    ''');

    batch.execute('''
      CREATE TABLE document_tags (
        document_id INTEGER NOT NULL REFERENCES documents(id) ON DELETE CASCADE,
        tag_id INTEGER NOT NULL REFERENCES tags(id) ON DELETE CASCADE,
        PRIMARY KEY (document_id, tag_id)
      );
    ''');

    batch.execute('''
      CREATE TABLE hidden_tag_index (
        tag_hash BLOB NOT NULL,
        document_id INTEGER NOT NULL REFERENCES documents(id) ON DELETE CASCADE,
        encrypted_name BLOB,
        encrypted_name_nonce BLOB,
        encrypted_name_mac BLOB,
        PRIMARY KEY (tag_hash, document_id)
      );
    ''');
    batch.execute('CREATE INDEX idx_hidden_tag_hash ON hidden_tag_index(tag_hash);');

    batch.execute('''
      CREATE VIRTUAL TABLE documents_fts USING fts5(
        ocr_text,
        original_name
      );
    ''');

    batch.execute('''
      CREATE TABLE vault_meta (
        key TEXT PRIMARY KEY,
        value TEXT NOT NULL
      );
    ''');

    batch.execute(_createNotesTableSql);
    for (final sql in _createNotesIndexesSql) {
      batch.execute(sql);
    }
    batch.execute(_createNotesFtsSql);

    await batch.commit(noResult: true);
  }

  static Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      final batch = db.batch();
      batch.execute('''
        CREATE TABLE folders (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          name TEXT NOT NULL UNIQUE,
          color TEXT,
          created_at INTEGER NOT NULL
        );
      ''');
      batch.execute('ALTER TABLE documents ADD COLUMN folder_id INTEGER REFERENCES folders(id) ON DELETE SET NULL;');
      batch.execute('CREATE INDEX idx_documents_folder ON documents(folder_id);');
      await batch.commit(noResult: true);
    }
    if (oldVersion < 3) {
      await db.execute('DROP TABLE IF EXISTS documents_fts;');
      await db.execute('''
        CREATE VIRTUAL TABLE documents_fts USING fts5(
          ocr_text,
          original_name
        );
      ''');
      await db.execute('''
        INSERT INTO documents_fts(rowid, ocr_text, original_name)
        SELECT id, COALESCE(ocr_text, ''), original_name FROM documents;
      ''');
    }
    if (oldVersion < 4) {
      final batch = db.batch();
      batch.execute(_createNotesTableSql);
      for (final sql in _createNotesIndexesSql) {
        batch.execute(sql);
      }
      batch.execute(_createNotesFtsSql);
      await batch.commit(noResult: true);
    }
  }
}
