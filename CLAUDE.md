# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project

SecDockKeeper is a local-first, end-to-end encrypted document vault built with Flutter (Dart SDK ^3.10.8, Flutter 3.38+). Android is the primary target; iOS and macOS build; web/Linux/Windows are explicitly unsupported by the storage layer (depends on SQLCipher + path_provider's app support directory).

## Common commands

```bash
flutter pub get                         # install Dart packages and platform pods
flutter analyze                         # lint (uses package:flutter_lints/flutter.yaml)
flutter test                            # run all tests
flutter test test/widget_test.dart      # run a single test file
flutter test --name "<substring>"       # run tests whose name matches
flutter run -d <device-id>              # run on a device/emulator
flutter build apk --debug --target-platform android-arm64 --split-per-abi
# Debug APK output: build/app/outputs/flutter-apk/app-arm64-v8a-debug.apk
```

There is no separate code generation step (no build_runner). The OCR plugin (`google_mlkit_text_recognition`) and `sqflite_sqlcipher` require a real Android device or emulator — they will not run in pure-Dart unit tests.

## Architecture

### Dependency wiring (`lib/app/`)

`main.dart` resolves `VaultPaths`, constructs a `VaultService`, loads `LockSettings`, and bundles them into `AppServices`. `AppServices` is exposed through an `InheritedWidget` (`AppScope`) — call `AppScope.of(context)` from any widget to reach repositories and services. Most service fields on `AppServices` are `late final` and lazily instantiated, so adding a new repository/service means a one-line field there plus the InheritedWidget consumers will pick it up.

`SecDockKeeperApp` (in `app/app.dart`) is a single-widget router driven by `VaultService` (a `ChangeNotifier`): `VaultState.uninitialized → OnboardingScreen`, `locked → LockScreen`, `unlocked → DocumentsListScreen`. There is no `go_router`/named-route system — navigation inside the unlocked state is plain `Navigator.push`.

### Vault lifecycle (`lib/features/vault/`, `lib/core/crypto/`)

`VaultService` owns the secret material in memory: the `KEK` (AES-256 key from Argon2id), the `_tagHmacKey` (HKDF-derived from KEK for hidden-tag hashing), and the open `VaultDatabase` handle. **Anything that touches user data must go through `VaultService.crypto`, `vault.kek`, `vault.tagHmac`, `vault.db`, or `vault.blobStore` — never re-derive keys or open the DB elsewhere.**

The flow:

1. `Kdf.deriveKek(password, salt)` runs Argon2id (default `m=19 MiB`, `t=2`, `p=1` per OWASP minimum — bumping these in `KdfParams.defaultParams` slows unlock).
2. The same KEK bytes are base64-encoded and used as the SQLCipher password (see `_kekToDbPassword`). One password unlocks both the file blobs and the metadata DB.
3. Per-document DEKs are random 32-byte keys, wrapped under the KEK with AES-GCM, stored alongside metadata in the `documents` table. File blobs (`blobs/<uuid>.enc`) are AES-GCM with the DEK.
4. `vault.json` (the descriptor) stores only Argon2 salt + KDF params. It is plaintext and useless without the password.

`AutoLockController` is a `WidgetsBindingObserver` that calls `vault.lock()` on `paused`/`hidden`/`inactive` based on `LockSettings.autoLockSeconds` (0 = immediate). `vault.lock()` clears the KEK, tag HMAC, and closes the DB — all secret material lives only on the `VaultService` instance.

### Storage layout (`lib/core/storage/`)

- `VaultPaths` resolves to `<applicationSupportDirectory>/secdockeeper/`, with `vault.db` (SQLCipher) and `blobs/<uuid>.enc` (AES-GCM ciphertext) inside.
- `VaultDatabase` is at schema version 3. Schema includes `documents`, `folders`, `tags` + `document_tags` join, `hidden_tag_index` (HMAC-only deniable tags), and an FTS5 virtual table `documents_fts(ocr_text, original_name)`. Migrations are in `_onUpgrade` — bump the `version:` and add an `if (oldVersion < N)` block when changing schema. The FTS table was rebuilt in v3, so any future column changes likely need the same drop-and-reindex pattern.
- Foreign keys are enabled (`PRAGMA foreign_keys = ON`); deletions cascade through `document_tags` and `hidden_tag_index`.

### Feature layout (`lib/features/`)

Each feature is a self-contained folder usually with a `*_repository.dart` (DB-backed CRUD via `vault.db`), a model class, and screens/sheets. Repositories take a `VaultService` directly so they can read the live DB handle and crypto helpers. Cross-feature behaviour (e.g. the importer reading OCR + classifier) is composed in `AppServices` rather than via service locators.

- `documents/` — `DocumentImportService` is the canonical write path: OCR → classify → generate DEK → wrap → encrypt blob → insert row. `DocumentOpenService` is the canonical read path and handles the temp-file dance for the system viewer.
- `hidden_tags/` — tags stored as `HMAC(tagHmacKey, name)` with an AES-GCM-encrypted name blob. They are revealed only when the exact name is typed into search; never enumerate or count them in UI. The HMAC key is HKDF-derived from KEK in `tag_hmac.dart::deriveTagHmacKey`.
- `sharing/` — exporting re-encrypts under a fresh DEK and emits `.sdkblob` + separate `.sdkkey.json`. Importing rewraps under the recipient's KEK.
- `backup/` — full-vault ZIP export/restore (the encrypted blobs + DB; no key material).
- `ocr/` — `OcrService` wraps Google ML Kit text recognition; `AutoClassifier` is keyword-based.
- `security/` — biometric unlock seals the master password in the platform keystore via `flutter_secure_storage`.

### Conventions to preserve

- Use **Conventional Commits** for all git history (e.g., `feat:`, `fix:`, `docs:`, `refactor:`, `chore:`).
- Refer to [ROADMAP.md](ROADMAP.md) at the root for planned features and security enhancements.
- Decrypted plaintext is short-lived: in memory during import re-encryption, and in a temp file while a system viewer reads it. The temp directory is wiped on lock — don't introduce long-lived plaintext caches.
- Don't add code paths that bypass `VaultService.lock()` — the assumption that `_kek`/`_vaultDb` go null on lock is load-bearing for the `state` getter and screen routing.
- Hidden tags must not appear in any list, autocomplete, or count surface; treat them as a search-only feature.
