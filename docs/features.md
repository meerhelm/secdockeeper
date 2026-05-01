# Features

This page is a feature-by-feature walkthrough — what each feature does, the
files involved, the data it reads/writes, and the non-obvious bits.

For the cryptographic detail behind any of these, see
[`security.md`](security.md). For the SQL schema and on-disk layout, see
[`storage.md`](storage.md).

## Onboarding

The first-run flow that creates a vault from scratch (or restores from a
backup) and optionally enables biometric unlock.

**Files:** [`features/onboarding/`](../lib/features/onboarding/)

**Cubit:** `OnboardingCubit` — see
[`state-management.md`](state-management.md#oncubitclass-state-diagrams) for
the state diagram.

**Flow:**

1. User enters a master password (8+ chars) and confirms.
2. `OnboardingCubit.create(password)` checks if biometric is available on
   the device.
3. If yes, the cubit emits `askBiometric: true`. The screen's
   `BlocListener` shows the "Enable biometric unlock?" dialog. The user
   chooses Skip or Enable; the screen calls `cubit.resolveBiometric(accepted)`.
4. The cubit calls `InitializeVaultUseCase(password)`. If the user accepted,
   it then calls `EnableBiometricsUseCase(password)` to seal the password
   in the platform keystore.
5. `vault.initialize()` notifies → `GoRouter` redirect → user lands on
   `/documents`.

If biometric is unavailable, the cubit calls `InitializeVaultUseCase`
directly — same redirect.

**Restore path:** the "Restore from backup" button picks a `.zip` file and
calls `cubit.restore(file)`. `RestoreBackupUseCase` extracts the archive
into the vault root and calls `vault.notifyExternalChange()` — the redirect
moves the user to `/lock` to unlock with their existing password.

**Behavior fix from the cubit migration:** in the original `setState`
implementation, `vault.initialize()` ran *before* the dialog, and the
async `notifyListeners` would race with the dialog's render — sometimes
the dialog never appeared. The cubit version checks biometric availability
first and only initializes after the user has answered. See
[`architecture.md`](architecture.md) commit history for context.

## Lock screen

The screen shown whenever the vault is `locked` (existing vault, no active
session).

**Files:** [`features/vault/lock_screen.dart`](../lib/features/vault/lock_screen.dart),
[`features/vault/cubit/lock_cubit.dart`](../lib/features/vault/cubit/lock_cubit.dart),
[`features/vault/cubit/lock_state.dart`](../lib/features/vault/cubit/lock_state.dart)

**Cubit:** `LockCubit` with state class `VaultLockState`.

**Flow:**

1. `LockCubit.init()` runs on screen mount. It calls
   `IsBiometricUnlockReadyUseCase` — both *enabled* in settings AND
   *available* on this device. If yes:
   - `state.biometricAvailable = true`, the "Use biometric" button appears
   - `tryBiometric()` runs immediately so the platform prompt pops without
     requiring a tap
2. Manual unlock: user types password, taps Unlock → `cubit.submit(password)`
   → `UnlockVaultUseCase` → `vault.unlock` notifies → redirect → `/documents`.
3. `BiometricUnlockUseCase` returns one of five results:
   - `Success` — vault unlocks, redirect handles the rest
   - `Cancelled` — clear busy, do nothing else (user dismissed the prompt)
   - `NoStoredPassword` — biometric was enabled but the keychain entry is
     missing; show the manual password field
   - `InvalidStoredPassword` — stored password no longer unlocks (master
     was changed elsewhere?); biometric is disabled as a side effect
   - `Failed(error)` — surfaced as an error message

The biometric-disabling side effect on `InvalidStoredPassword` lives inside
the use case so multiple call sites can't forget it.

## Documents list

The home screen after unlock. Search bar, folder filter, tag filter, FAB
to import.

**Files:** [`features/documents/documents_list_screen.dart`](../lib/features/documents/documents_list_screen.dart),
[`features/documents/cubit/`](../lib/features/documents/cubit/)

**Cubit:** `DocumentsListCubit` with state class `DocumentsListState`.

**State held:**
- `documents` — current list, recomputed on any filter change or DB change
- `folders`, `allTags` — for the folder chip row and tag filter sheet
- `query`, `activeTagIds`, `folderScope` — current filters
- `busy`, `error`, `message` — for one-shot operation feedback

**Actions:**
- `setQuery`, `clearQuery`, `setFolderScope`, `toggleTagFilter`,
  `clearTagFilter` — all trigger `_refreshDocuments()`
- `importFiles(List<ImportFileInput>)` — multi-file import via FilePicker
- `importSharedPackage({blobFile, keyFile})` — receive a shared document
- `exportBackup` — full-vault zip export and share
- `lock` — explicit lock (clears temp dir, locks vault → router redirects)
- `createFolder(name)` — creates a folder; the screen then sets folder scope

**Reactivity:** the cubit subscribes to `documents.changes` and
`folders.changes`. Any insert/update/delete on those tables fires a refresh.
The `tags` list is loaded once at construction and re-loaded only when the
user opens the tag filter sheet (`refreshAllTags`).

**Search merge logic:** when `query` is non-empty, `SearchDocumentsUseCase`
runs three queries in parallel — FTS, visible-tag name match, hidden-tag
HMAC match — and merges deduplicated results with tag matches first. This
means typing a hidden tag name in the search bar surfaces those documents,
which is the **only** way the UI ever reveals hidden-tagged documents.

## Document detail

Single-document screen with metadata, folder, tags, and three primary
actions: open decrypted, share encrypted, manage hidden tags.

**Files:** [`features/documents/document_detail_screen.dart`](../lib/features/documents/document_detail_screen.dart),
[`features/documents/cubit/document_detail_cubit.dart`](../lib/features/documents/cubit/document_detail_cubit.dart)

**Cubit:** `DocumentDetailCubit`. Constructed with the document `id` from
the route's path parameter.

**Reactivity:** subscribes to all three change streams (`documents`,
`folders`, `tags`) so the screen stays fresh when the user reassigns a
folder via the picker sheet, removes a tag, etc.

**Pop signal:** after a successful delete, the cubit emits
`popRequested: true`. The screen's `BlocListener` calls `context.pop()`
and the user lands back on the list.

**Sub-surfaces** opened from this screen:
- `FolderPickerSheet.show(context, doc.id, doc.folderId)`
- `TagPickerSheet.show(context, doc.id)`
- `HiddenTagsSheet.show(context, doc.id)`

Each is its own cubit; see [Sheets](#sheets) below.

## Sheets

### Folder picker

[`features/folders/folder_picker_sheet.dart`](../lib/features/folders/folder_picker_sheet.dart)

`FolderPickerSheet.show(context, documentId, currentFolderId)` opens the
sheet with its own `FolderPickerCubit`. The cubit lists folders, lets the
user select one (assigns + emits `popRequested`), create a new one (creates
+ assigns + pops), or rename / delete an existing one via long-press.

### Tag picker

[`features/tags/tag_picker_sheet.dart`](../lib/features/tags/tag_picker_sheet.dart)

`TagPickerSheet.show(context, documentId)`. The cubit holds `allTags`,
`assignedIds`, and a search `query`. Search filters the list locally; if
no exact match exists, a "Create '...'" item appears to upsert a new tag
and assign it. Toggling a checkbox calls `toggleAssign(tagId, assign)`
which dispatches to `AssignTagUseCase` or `UnassignTagUseCase`.

### Hidden tags

[`features/hidden_tags/hidden_tags_sheet.dart`](../lib/features/hidden_tags/hidden_tags_sheet.dart)

`HiddenTagsSheet.show(context, documentId)`. The cubit lists this
document's hidden tag plaintexts (decrypted from the per-row sealed name
column) and lets the user add or remove. **There is no equivalent surface
for "all hidden tags across all documents"** — that would defeat the
deniability.

## Folders feature (model side)

A flat list of folders. No nesting (intentional — flat scales better for
mobile and avoids the "where did I put it" hunt).

**Files:** [`features/folders/`](../lib/features/folders/)

**Repository methods:** `listAll`, `getById`, `create`, `rename`, `delete`,
`assignDocument(documentId, folderId)`, `countWithoutFolder`. The
repository emits on `changes` after every mutation.

**FK behaviour:** `documents.folder_id REFERENCES folders(id) ON DELETE SET NULL`.
Deleting a folder demotes its documents to "no folder" rather than orphaning
or deleting them.

**Folder scope** ([`features/documents/folder_scope.dart`](../lib/features/documents/folder_scope.dart))
is a small value class with three variants: `all`, `unassigned`, `specific(id)`.
The list screen uses it to drive the chip row and pass filters into
`SearchDocumentsUseCase`.

## Tags feature

Many-to-many between documents and visible tags. Searchable, filterable,
listable.

**Files:** [`features/tags/`](../lib/features/tags/)

**Repository methods:** `listAll`, `forDocument`, `upsert`, `assign`,
`unassign`, `delete`, `findDocumentsByQuery(query)` (used by
`SearchDocumentsUseCase` for tag-name search).

`upsert` is case-insensitive — typing "Work" then "work" gives the same tag.

## Hidden tags feature

The deniable variant of tags. Stored as `HMAC(tagHmacKey, name)` plus an
AES-GCM-sealed name blob keyed off the KEK. Read [`security.md`](security.md#hidden-tags)
end-to-end before changing anything here.

**Files:** [`features/hidden_tags/`](../lib/features/hidden_tags/)

**Repository methods:** `assignByName(documentId, name)`,
`removeByName(documentId, name)`, `removeByHash(documentId, hash)`,
`namesForDocument(documentId)`,
`findDocumentsByName(name)`. Note the absence of "list all hidden tags".

**The HMAC key** is HKDF-derived from the KEK in
[`tag_hmac.dart::deriveTagHmacKey`](../lib/core/crypto/tag_hmac.dart). It's
held on `VaultService._tagHmacKey` and cleared on `lock()` along with the
KEK.

## OCR + auto-classification

On import, image documents are run through Google ML Kit's text recognition
(local, on-device) and a small keyword-based classifier guesses a category.

**Files:** [`features/ocr/`](../lib/features/ocr/)

- `OcrService` — wraps `google_mlkit_text_recognition`. Returns `null` on
  unsupported platforms (the plugin only loads on Android/iOS).
- `AutoClassifier` — pure-Dart keyword matcher. Looks at OCR text and the
  filename to guess: `passport`, `invoice`, `contract`, `tax`, etc.

The OCR text is stored on `documents.ocr_text` and indexed via the
`documents_fts` virtual table — that's how a search for "berlin" matches a
photographed invoice. The classification appears as a small chip on the
document card and detail screen.

OCR cannot run in pure-Dart unit tests; the plugin needs the platform
binary. Integration testing is done on a device.

## Sharing

Per-document encrypted export and import. The format is described in
[`security.md`](security.md#sharing-format).

**Files:** [`features/sharing/`](../lib/features/sharing/)

**Why two files (`.sdkblob` + `.sdkkey.json`)?** The blob is harmless without
the key. Send them over different channels — chat the blob, email the key
— so capturing one doesn't reveal the document. The recipient's app
re-imports through `DocumentImportService`, which generates a fresh
KEK-wrapped DEK; the original shared DEK is discarded.

## Backup

Full-vault portable archive. The encrypted blobs and SQLCipher database go
into a zip; the master password is required to unlock the restored vault.

**Files:** [`features/backup/`](../lib/features/backup/)

**Export flow:**
1. `ExportBackupUseCase` calls `DocumentOpenService.deleteAllTemp()` to wipe
   any plaintext temp files.
2. `BackupService.exportVault()` first locks the vault (so SQLite isn't
   actively writing during the zip), then walks the vault root and writes
   every file into a zip with a manifest.
3. The user is handed the zip via the system share sheet.

**Restore flow:**
1. Only allowed when there's no existing vault (
   `_vault.state == VaultState.uninitialized`).
2. `BackupService.restoreFromArchive(file)` validates the manifest version,
   wipes the vault root, and extracts the archive — then calls
   `_vault.notifyExternalChange()` so the router redirect kicks in and the
   user is moved to `/lock`.

**Path traversal:** every archive entry's resolved path is verified to be
inside the vault root via `_assertWithinRoot`. A malicious archive with
`../../etc/passwd` entries gets rejected.

## Biometrics

Optional fingerprint / Face ID unlock. The master password is sealed in
the platform keystore — Keychain on iOS, EncryptedSharedPreferences on
Android — via `flutter_secure_storage`.

**Files:** [`features/security/biometric_service.dart`](../lib/features/security/biometric_service.dart),
[`features/security/lock_settings.dart`](../lib/features/security/lock_settings.dart)

**Settings persisted:**
- `sdk.biometric_enabled` — `"true"` or `"false"`
- `sdk.master_password` — only present when biometric is enabled
- `sdk.auto_lock_seconds` — integer, default 60

`LockSettings.readStoredPassword` returns `null` if biometric is disabled,
which is the safety net `BiometricUnlockUseCase` relies on for the
`NoStoredPassword` result.

## Auto-lock

[`features/security/auto_lock_controller.dart`](../lib/features/security/auto_lock_controller.dart)

`AutoLockController` is a `WidgetsBindingObserver` started in `main.dart`
via `services.autoLock.start()`. On `paused`, `hidden`, or `inactive` it
schedules `vault.lock()` after `LockSettings.autoLockSeconds`. If the app
returns to the foreground before the timer fires, the timer is cancelled.

`autoLockSeconds: 0` means "lock immediately" — useful for high-paranoia
profiles.

The controller is not connected to a cubit because it operates on app
lifecycle, not user actions. It reads from `LockSettings` directly and
calls `vault.lock()` directly.
