# Storage layer

Documents live in two places on disk: encrypted blobs in the filesystem and
metadata + indexes in a SQLCipher database. This page covers the on-disk
layout, the schema, the migration policy, and the FTS index.

## Filesystem layout

[`VaultPaths`](../lib/core/storage/paths.dart) resolves the vault root to
`<applicationSupportDirectory>/secdockeeper/`. On Android that's
`/data/data/<pkg>/files/secdockeeper/`; on iOS, the app's Application Support
directory. **Web, Linux, and Windows are unsupported** because the
`path_provider` plugin does not return a usable application support directory
there, and the app uses SQLCipher which is platform-native.

Inside the vault root:

```
secdockeeper/
├─ vault.json            ← Argon2 salt + KDF params (plaintext, useless alone)
├─ vault.db              ← SQLCipher metadata DB (encrypted)
└─ blobs/
   ├─ <uuid>.enc         ← AES-GCM-sealed file content, one per document
   ├─ <uuid>.enc
   └─ ...
```

Filenames in `blobs/` are random UUIDs (`uuid` v4) — they leak no information
about the document. Sizes are AES-GCM-sealed plaintext + a 12-byte nonce
upfront and a 16-byte MAC at the end (the `Aead` helper handles the framing
internally; see [`aead.dart`](../lib/core/crypto/aead.dart)).

`vault.json` is plaintext and contains:

```json
{
  "version": 1,
  "salt": "<base64 of 16 random bytes>",
  "kdf": { "m": 19456, "t": 2, "p": 1, "h": 32 }
}
```

It is useless without the master password — any attacker can read it but
needs to brute-force Argon2id with the published parameters. Hence the OWASP
defaults.

## SQLCipher metadata DB

Opened by
[`VaultDatabase.open`](../lib/core/storage/vault_database.dart) with the
KEK (base64-encoded) as the passphrase. `PRAGMA foreign_keys = ON` is set
in `onConfigure` so cascades work.

Current schema version: **3**. Tables:

### `documents`
The main metadata row. One per imported file.

```sql
CREATE TABLE documents (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  uuid TEXT NOT NULL UNIQUE,                  -- matches blobs/<uuid>.enc
  original_name TEXT NOT NULL,
  mime_type TEXT,
  size INTEGER NOT NULL,                       -- plaintext size
  dek_wrapped BLOB NOT NULL,                   -- AES-GCM(KEK, DEK)
  dek_nonce BLOB NOT NULL,
  dek_mac BLOB NOT NULL,
  file_nonce BLOB NOT NULL,                    -- AES-GCM nonce for the blob
  file_mac BLOB NOT NULL,
  ocr_text TEXT,                               -- result of OcrService
  classification_auto TEXT,                    -- AutoClassifier guess
  classification_manual TEXT,                  -- user override
  folder_id INTEGER REFERENCES folders(id) ON DELETE SET NULL,
  created_at INTEGER NOT NULL,                 -- ms since epoch
  updated_at INTEGER NOT NULL
);
CREATE INDEX idx_documents_created_at ON documents(created_at);
CREATE INDEX idx_documents_folder ON documents(folder_id);
```

### `folders`
Flat folder list. Foreign-keyed from `documents.folder_id` with `SET NULL`,
so deleting a folder moves its documents to "no folder" rather than deleting
them.

```sql
CREATE TABLE folders (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  name TEXT NOT NULL UNIQUE,
  color TEXT,
  created_at INTEGER NOT NULL
);
```

### `tags` + `document_tags`
Many-to-many between visible tags and documents. Both sides cascade so
deleting either end cleans up the join row.

```sql
CREATE TABLE tags (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  name TEXT NOT NULL UNIQUE,
  color TEXT,
  created_at INTEGER NOT NULL
);

CREATE TABLE document_tags (
  document_id INTEGER NOT NULL REFERENCES documents(id) ON DELETE CASCADE,
  tag_id      INTEGER NOT NULL REFERENCES tags(id)      ON DELETE CASCADE,
  PRIMARY KEY (document_id, tag_id)
);
```

### `hidden_tag_index`
Hidden tags. There is **no** parent `hidden_tags` table — these don't have
identity beyond their hash. See [`security.md`](security.md#hidden-tags).

```sql
CREATE TABLE hidden_tag_index (
  tag_hash BLOB NOT NULL,                       -- HMAC(tagHmacKey, name)
  document_id INTEGER NOT NULL REFERENCES documents(id) ON DELETE CASCADE,
  encrypted_name BLOB,                          -- AES-GCM(KEK, name)
  encrypted_name_nonce BLOB,
  encrypted_name_mac BLOB,
  PRIMARY KEY (tag_hash, document_id)
);
CREATE INDEX idx_hidden_tag_hash ON hidden_tag_index(tag_hash);
```

The index on `tag_hash` is what makes the search-bar lookup constant-time.

### `documents_fts`
SQLite FTS5 virtual table covering OCR text and original name. Used for
the free-text search box on the documents list.

```sql
CREATE VIRTUAL TABLE documents_fts USING fts5(
  ocr_text,
  original_name
);
```

Maintained by [`DocumentRepository`](../lib/features/documents/document_repository.dart):
- on `create` — insert with the row's `ocr_text` and `original_name`
- on `rename` — delete + re-insert with the new name
- on `updateOcrText` — delete + re-insert with the new OCR text
- on `deleteById` — delete the FTS row in the same transaction

Query strings are turned into FTS5 prefix-match terms by `_buildFtsQuery`:
each whitespace-separated token becomes `"word"*` and tokens are AND-ed.

### `vault_meta`
Reserved key/value store for future migration markers, feature flags, etc.
Currently unused.

## Migrations

Migrations live in `_onUpgrade` inside `VaultDatabase`:

- **v1 → v2**: introduced `folders` + `documents.folder_id` (with index)
- **v2 → v3**: dropped and recreated the FTS5 virtual table, then
  re-indexed by `INSERT INTO documents_fts SELECT ... FROM documents`. This
  pattern is the standard way to add columns to an FTS5 virtual table —
  any future change to the FTS schema needs the same drop-and-reindex.

Migration policy:

1. Bump the `version: N` constant in `VaultDatabase.open`.
2. Add `if (oldVersion < N) { ... }` in `_onUpgrade`.
3. Use `db.batch()` and `await batch.commit(noResult: true)` for idempotent
   multi-statement migrations.
4. If you change FTS columns, drop and rebuild — partial column changes are
   not supported by SQLite FTS5.
5. Ship the change in a single PR with a manual test note: "create vault on
   v(N-1), upgrade app, verify documents/tags/etc are intact".

There is no automated migration test suite. The DB doesn't open in pure-Dart
unit tests (it requires the SQLCipher native plugin), so migration testing
has to happen on a device or emulator.

## Blob store

[`BlobStore`](../lib/core/storage/blob_store.dart) is a thin wrapper over
the filesystem. It does not hold the KEK or DEK — it only knows where the
files live. Encryption happens at the layer above:

- `DocumentImportService` calls `vault.crypto.encryptBlob(dek, plaintext)`
  → `Aead.seal` and writes `sealed.ciphertext` via `BlobStore.write`.
- `DocumentOpenService.decryptBytes` reads the bytes, unwraps the DEK, and
  calls `vault.crypto.decryptBlob(dek, sealed)` → `Aead.open`.

`BlobStore.delete` is fire-and-forget: missing files are not an error
(they're already gone). This is intentional — `DeleteDocumentUseCase`
deletes the blob *before* the DB row, so a crash mid-delete leaves an
orphan row pointing at a missing blob, which the open path will surface as
an error rather than silently corrupting state.

## What's encrypted vs. what's not

| Item | Where | Encryption |
| --- | --- | --- |
| Document plaintext | `blobs/<uuid>.enc` | AES-256-GCM(DEK) |
| DEK | column in `documents` | AES-256-GCM(KEK) — wrapped |
| Document name, MIME, size, OCR | columns in `documents` | SQLCipher (whole-DB encryption with KEK) |
| Tag names | column in `tags` | SQLCipher |
| Folder names | column in `folders` | SQLCipher |
| Hidden tag name | column in `hidden_tag_index` | AES-256-GCM(KEK) — explicit per-row sealed name |
| Hidden tag hash | column in `hidden_tag_index` | HMAC(tagHmacKey, name) |
| Argon2 salt + params | `vault.json` | **plaintext** (intentional) |
| Application Support directory itself | filesystem | platform-default app sandbox only |

Note that SQLCipher encrypts the *file* (page-by-page), so SQL-level fields
are protected at rest. Hidden tag names get an extra layer because their
plaintext is a high-value target — the SQLCipher layer falls away the moment
the DB is unlocked, but the per-row AES-GCM seal stays.

## Things to avoid

- **Don't open the DB outside `VaultService`.** There is exactly one path
  from password to opened `Database`. Adding a second path is how you end up
  with two stale handles, mismatched migrations, or a leaked KEK.
- **Don't store plaintext anywhere on disk.** No "draft" of a document, no
  "recently opened" thumbnail, no decrypted cache. The temp file written by
  `DocumentOpenService` is the only allowed plaintext-on-disk surface.
- **Don't change the FTS column set without dropping and rebuilding the
  table.** SQLite FTS5 doesn't support `ALTER TABLE` for virtual tables.
- **Don't use the raw KEK as the SQLCipher passphrase directly.** Use the
  `_kekToDbPassword` base64 wrapper that `VaultService` already does — it's
  the documented way and the format is part of the on-disk contract.
