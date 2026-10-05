# Technical Specification

## 1. Architecture

### System Overview

Single-codebase Flutter app organised in feature folders, layered Screen → Cubit → UseCase → Repository/Service. `VaultService` owns all secret material (KEK, tag-HMAC key, open SQLCipher handle) and is the only place keys are derived or the DB is opened. Detailed write-ups: `docs/architecture.md`, `docs/state-management.md`, `docs/routing.md`, `docs/storage.md`, `docs/security.md`.

### Directory Structure

```
lib/
├── main.dart
├── app/                # AppServices container, AppScope InheritedWidget, router, shared widgets
├── core/
│   ├── crypto/         # Kdf (Argon2id), Aead (AES-GCM), tag HMAC derivation
│   ├── storage/        # VaultPaths, VaultDatabase (SQLCipher, migrations, FTS5)
│   └── logging/
└── features/<feature>/ # repository + model + cubit/ + usecases/ + screens
    (backup, documents, folders, hidden_tags, notes, ocr, onboarding, scanner,
     security, settings, sharing, tags, vault)
test/
└── features/<feature>/usecases/   # mirrors lib/ one-for-one
```

### Key Design Decisions

| Decision | Choice | Rationale |
|----------|--------|-----------|
| Key derivation | Argon2id → KEK, also used (base64) as SQLCipher passphrase | One password unlocks both metadata and blobs |
| Per-document keys | Random 32-byte DEK wrapped under KEK with AES-GCM | Re-sharing and rekeying touch one document at a time |
| Hidden tags | `HMAC(tagHmacKey, name)` + encrypted name blob | Deniability: no enumerable list exists |
| State management | `flutter_bloc` cubits over use cases | Use cases stay pure Dart and mockable |
| DI | `AppServices` with lazy `late final` fields exposed through `AppScope` | No service locator, no global state in tests |

## 2. Data Model

SQLCipher database `vault.db` (schema version tracked in `VaultDatabase`): `documents`, `folders`, `tags` + `document_tags`, `hidden_tag_index`, notes, and the FTS5 table `documents_fts`. Foreign keys are on; deletes cascade. Migrations live in `_onUpgrade`; FTS column changes need the drop-and-reindex pattern. Blobs are `blobs/<uuid>.enc`. See `docs/storage.md`.

## 3. API / Interface Design

Each use case exposes a single `call()` and takes repositories/services through its constructor. Catalogue: `docs/usecases.md`.

## 4. Key Patterns

### State Management
One cubit per screen or sheet; cubits subscribe to repository change streams and dispatch every action to a use case (`docs/state-management.md`).

### Error Handling
Errors are caught at the cubit boundary and logged through `core/logging`; secret material is never included in log output.

### Testing Strategy
Use cases carry the test suite; see `specs/testing-spec.md`.

## 5. Dependencies

| Package | Version | Purpose |
|---------|---------|---------|
| cryptography / cryptography_flutter | 2.9.0 / 2.3.4 | Argon2id, AES-GCM, HKDF, HMAC |
| sqflite_sqlcipher | 3.4.0 | Encrypted metadata DB with FTS5 |
| flutter_secure_storage | 10.2.0 | Platform keystore for biometric unlock |
| local_auth | 3.0.1 | Biometric prompt |
| google_mlkit_text_recognition | 0.15.1 | On-device OCR |
| cunning_document_scanner | 1.4.0 | Camera document scanning |
| archive | 4.0.9 | Backup ZIP export/restore |
| flutter_bloc | 9.1.1 | Cubits |
| go_router | 17.2.3 | Navigation |
| logger | 2.7.0 | Logging |

## 6. Risks & Considerations

- SQLCipher, ML Kit and the platform keystore do not run in pure-Dart tests; migrations and repository changes need on-device verification.
- Raising Argon2id parameters slows unlock on low-end devices.
- Any new plaintext surface (cache, thumbnail, temp file) must be wiped on lock.

## Architecture Decision Records

| Decision | Options Considered | Choice | Rationale |
|----------|-------------------|--------|-----------|
| Spec process | Ad-hoc issues, dev-process-toolkit SDD | dev-process-toolkit, `mode: none` | Specs and plans live in the repo next to the code; GitHub issues stay the backlog |
