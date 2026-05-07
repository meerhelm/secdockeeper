# Use cases registry

Every imperative action a screen takes — from "unlock the vault" to
"toggle this tag filter" — runs through exactly one use case class. This
page lists all of them, grouped by feature, with their dependencies and a
one-line description.

The shape is uniform: each class has a single public `call(...)` method
(usually with named parameters) and takes its dependencies via the
constructor. They are pure Dart with no `BuildContext` and no I/O beyond
what their dependencies do — which means every one of them is mockable,
and every one has a test in `test/features/<feature>/usecases/`.

## Vault

| Use case | File | Dependencies | What it does |
| --- | --- | --- | --- |
| `InitializeVaultUseCase` | [`features/vault/usecases/initialize_vault.dart`](../lib/features/vault/usecases/initialize_vault.dart) | `VaultService` | First-run: derive KEK from password, open SQLCipher DB, write `vault.json`. |
| `UnlockVaultUseCase` | [`features/vault/usecases/unlock_vault.dart`](../lib/features/vault/usecases/unlock_vault.dart) | `VaultService` | Open the existing DB with a password. Returns `false` on bad password. |
| `LockVaultUseCase` | [`features/vault/usecases/lock_vault.dart`](../lib/features/vault/usecases/lock_vault.dart) | `VaultService`, `DocumentOpenService` | Wipe the temp viewer dir, then `vault.lock()`. |

## Security (biometrics, lock settings)

| Use case | File | Dependencies | What it does |
| --- | --- | --- | --- |
| `IsBiometricAvailableUseCase` | [`features/security/usecases/is_biometric_available.dart`](../lib/features/security/usecases/is_biometric_available.dart) | `BiometricService` | True if the OS supports + has enrolled biometrics. |
| `IsBiometricUnlockReadyUseCase` | [`features/security/usecases/is_biometric_unlock_ready.dart`](../lib/features/security/usecases/is_biometric_unlock_ready.dart) | `BiometricService`, `LockSettings` | True only when the user has *enabled* biometric AND the device supports it. |
| `EnableBiometricsUseCase` | [`features/security/usecases/enable_biometrics.dart`](../lib/features/security/usecases/enable_biometrics.dart) | `LockSettings` | Seal the master password into the platform keystore. |
| `BiometricUnlockUseCase` | [`features/security/usecases/biometric_unlock.dart`](../lib/features/security/usecases/biometric_unlock.dart) | `BiometricService`, `LockSettings`, `VaultService` | Authenticate, read stored password, unlock vault. Returns a sealed `BiometricUnlockResult` variant: `Success`, `Cancelled`, `NoStoredPassword`, `InvalidStoredPassword`, `Failed(error)`. On invalid stored password, biometric is disabled as a side effect. |

## Documents

| Use case | File | Dependencies | What it does |
| --- | --- | --- | --- |
| `SearchDocumentsUseCase` | [`features/documents/usecases/search_documents.dart`](../lib/features/documents/usecases/search_documents.dart) | `DocumentRepository`, `TagRepository`, `HiddenTagRepository` | Merges three sources when there's a query: FTS match, visible-tag match, hidden-tag HMAC match. Tag matches surface above FTS results. |
| `GetDocumentUseCase` | [`features/documents/usecases/get_document.dart`](../lib/features/documents/usecases/get_document.dart) | `DocumentRepository` | `getById(id)` — returns null if missing. |
| `ImportFilesUseCase` | [`features/documents/usecases/import_files.dart`](../lib/features/documents/usecases/import_files.dart) | `DocumentImportService` | Bulk dispatch: each input is `(name, bytes?, path?)`. Routes through `importBytes` or `importFile`. Returns count successfully imported. |
| `RenameDocumentUseCase` | [`features/documents/usecases/rename_document.dart`](../lib/features/documents/usecases/rename_document.dart) | `DocumentRepository` | Update `original_name` and the FTS row. |
| `DeleteDocumentUseCase` | [`features/documents/usecases/delete_document.dart`](../lib/features/documents/usecases/delete_document.dart) | `VaultService`, `DocumentRepository` | Delete blob first, then DB row. Order matters — see [`storage.md`](storage.md#blob-store). |
| `OpenDocumentUseCase` | [`features/documents/usecases/open_document.dart`](../lib/features/documents/usecases/open_document.dart) | `DocumentOpenService` | Decrypt to temp file and hand to `OpenFilex`. |
| `WatchDocumentChangesUseCase` | [`features/documents/usecases/watch_document_changes.dart`](../lib/features/documents/usecases/watch_document_changes.dart) | `DocumentRepository` | Exposes `repo.changes`. Subscribed by cubits to invalidate the list. |

## Folders

| Use case | File | Dependencies | What it does |
| --- | --- | --- | --- |
| `ListFoldersUseCase` | [`features/folders/usecases/list_folders.dart`](../lib/features/folders/usecases/list_folders.dart) | `FolderRepository` | Returns all folders with their document counts. |
| `GetFolderUseCase` | [`features/folders/usecases/get_folder.dart`](../lib/features/folders/usecases/get_folder.dart) | `FolderRepository` | `getById(id)`. Used by detail screen to display the assigned folder. |
| `CreateFolderUseCase` | [`features/folders/usecases/create_folder.dart`](../lib/features/folders/usecases/create_folder.dart) | `FolderRepository` | Idempotent (name match returns existing). |
| `RenameFolderUseCase` | [`features/folders/usecases/rename_folder.dart`](../lib/features/folders/usecases/rename_folder.dart) | `FolderRepository` |  |
| `DeleteFolderUseCase` | [`features/folders/usecases/delete_folder.dart`](../lib/features/folders/usecases/delete_folder.dart) | `FolderRepository` | Documents inside cascade to "no folder" via `ON DELETE SET NULL`. |
| `AssignDocumentToFolderUseCase` | [`features/folders/usecases/assign_document_to_folder.dart`](../lib/features/folders/usecases/assign_document_to_folder.dart) | `FolderRepository` | Pass `folderId: null` to unassign. |
| `WatchFolderChangesUseCase` | [`features/folders/usecases/watch_folder_changes.dart`](../lib/features/folders/usecases/watch_folder_changes.dart) | `FolderRepository` | Stream subscription point. |

## Tags

| Use case | File | Dependencies | What it does |
| --- | --- | --- | --- |
| `ListAllTagsUseCase` | [`features/tags/usecases/list_all_tags.dart`](../lib/features/tags/usecases/list_all_tags.dart) | `TagRepository` | All tags, alphabetical. |
| `ListTagsForDocumentUseCase` | [`features/tags/usecases/list_tags_for_document.dart`](../lib/features/tags/usecases/list_tags_for_document.dart) | `TagRepository` | Tags assigned to one document. |
| `UpsertTagUseCase` | [`features/tags/usecases/upsert_tag.dart`](../lib/features/tags/usecases/upsert_tag.dart) | `TagRepository` | Find-or-create by name (case-insensitive). |
| `AssignTagUseCase` | [`features/tags/usecases/assign_tag.dart`](../lib/features/tags/usecases/assign_tag.dart) | `TagRepository` | Insert into `document_tags`, ignore conflict. |
| `UnassignTagUseCase` | [`features/tags/usecases/unassign_tag.dart`](../lib/features/tags/usecases/unassign_tag.dart) | `TagRepository` |  |
| `WatchTagChangesUseCase` | [`features/tags/usecases/watch_tag_changes.dart`](../lib/features/tags/usecases/watch_tag_changes.dart) | `TagRepository` | Stream subscription point. |

## Hidden tags

| Use case | File | Dependencies | What it does |
| --- | --- | --- | --- |
| `ListHiddenTagsForDocumentUseCase` | [`features/hidden_tags/usecases/list_hidden_tags_for_document.dart`](../lib/features/hidden_tags/usecases/list_hidden_tags_for_document.dart) | `HiddenTagRepository` | Decrypts the per-row sealed names for one document. **There is no equivalent for "all hidden tags".** See [`security.md`](security.md#hidden-tags). |
| `AssignHiddenTagUseCase` | [`features/hidden_tags/usecases/assign_hidden_tag.dart`](../lib/features/hidden_tags/usecases/assign_hidden_tag.dart) | `HiddenTagRepository` | HMACs the name, AES-GCM-seals the plaintext, inserts. |
| `RemoveHiddenTagUseCase` | [`features/hidden_tags/usecases/remove_hidden_tag.dart`](../lib/features/hidden_tags/usecases/remove_hidden_tag.dart) | `HiddenTagRepository` | Recomputes the HMAC and deletes by hash. |
| `WatchHiddenTagChangesUseCase` | [`features/hidden_tags/usecases/watch_hidden_tag_changes.dart`](../lib/features/hidden_tags/usecases/watch_hidden_tag_changes.dart) | `HiddenTagRepository` | Stream subscription point. |

## Sharing

| Use case | File | Dependencies | What it does |
| --- | --- | --- | --- |
| `ShareDocumentUseCase` | [`features/sharing/usecases/share_document.dart`](../lib/features/sharing/usecases/share_document.dart) | `ShareService` | Re-encrypt under a fresh DEK, write `.sdkblob` + `.sdkkey.json`, hand both to system share sheet. |
| `ImportSharedPackageUseCase` | [`features/sharing/usecases/import_shared_package.dart`](../lib/features/sharing/usecases/import_shared_package.dart) | `ShareService` | Decrypt blob using DEK from JSON, then re-import via `DocumentImportService` — which generates yet another fresh DEK wrapped under the recipient's KEK. |

## Backup

| Use case | File | Dependencies | What it does |
| --- | --- | --- | --- |
| `ExportBackupUseCase` | [`features/backup/usecases/export_backup.dart`](../lib/features/backup/usecases/export_backup.dart) | `BackupService`, `DocumentOpenService` | Wipe temp viewer dir, lock the vault (forced inside `exportVault`), zip the whole vault root, share via system share sheet. |
| `RestoreBackupUseCase` | [`features/backup/usecases/restore_backup.dart`](../lib/features/backup/usecases/restore_backup.dart) | `BackupService` | Validate manifest, replace vault root contents, call `notifyExternalChange()` so the router redirect picks up the new descriptor. Only allowed when no vault exists. |

## Why so many trivial wrappers?

Some use cases are one-line forwarders (`ListFoldersUseCase` is just
`_repo.listAll()`). Three reasons not to inline them:

1. **Uniform shape.** Every cubit takes use cases. Changing one repo method
   doesn't ripple into N cubits — only into the use cases that wrap that
   method.
2. **Easy to mock.** A cubit test can swap a use case for a stub without
   touching the underlying repo.
3. **Explicit dependencies.** A cubit's constructor lists exactly the
   operations it performs. New readers can audit a cubit's surface area in
   ten seconds.

The cost is verbosity in [`router.dart`](../lib/app/router.dart) where each
cubit's use cases are constructed inline. That cost is paid once at the
composition root, not in every screen.
