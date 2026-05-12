import 'package:sqflite_sqlcipher/sqflite.dart';

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
    return VaultDatabase._(database);
  }

  Future<void> close() => _db.close();

  Future<void> rekey(String newPassword) async {
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

    batch.execute('''
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
    ''');
    batch.execute('CREATE INDEX idx_notes_updated_at ON notes(updated_at);');
    batch.execute('CREATE INDEX idx_notes_folder ON notes(folder_id);');
    batch.execute('''
      CREATE VIRTUAL TABLE notes_fts USING fts5(
        title
      );
    ''');

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
      batch.execute('''
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
      ''');
      batch.execute('CREATE INDEX idx_notes_updated_at ON notes(updated_at);');
      batch.execute('CREATE INDEX idx_notes_folder ON notes(folder_id);');
      batch.execute('''
        CREATE VIRTUAL TABLE notes_fts USING fts5(
          title
        );
      ''');
      await batch.commit(noResult: true);
    }
  }
}
