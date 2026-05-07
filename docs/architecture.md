# Architecture

SecDockKeeper is a single-codebase Flutter app organised in feature folders.
This page covers the layering, the dependency container, the dataflow on a
typical action, and the rules that keep secrets where they belong.

## Layers

```
┌───────────────────────────────────────────────────────────┐
│  Screen / Sheet (StatefulWidget or StatelessWidget)       │
│    – pure UI, controllers for text fields, dialogs        │
│    – reads cubit state via BlocBuilder/BlocConsumer       │
│    – dispatches via context.read<XCubit>().<action>()     │
└──────────────────────────┬────────────────────────────────┘
                           │
┌──────────────────────────▼────────────────────────────────┐
│  Cubit (one per screen, one per sheet)                    │
│    – holds in-memory state for the screen                 │
│    – subscribes to repository change streams              │
│    – calls UseCases for every action                      │
└──────────────────────────┬────────────────────────────────┘
                           │
┌──────────────────────────▼────────────────────────────────┐
│  UseCase                                                  │
│    – one operation, one public method (call())            │
│    – takes repositories/services via constructor          │
│    – pure Dart, fully mockable                            │
└──────────────────────────┬────────────────────────────────┘
                           │
┌──────────────────────────▼────────────────────────────────┐
│  Repository / Service                                     │
│    – DocumentRepository, FolderRepository, etc — DB CRUD  │
│    – DocumentImportService, ShareService, BackupService — │
│      orchestrate crypto + filesystem + DB                 │
└──────────────────────────┬────────────────────────────────┘
                           │
┌──────────────────────────▼────────────────────────────────┐
│  Core (crypto, storage)                                   │
│    – Kdf, VaultCrypto, Aead, TagHmac                      │
│    – VaultDatabase (SQLCipher), BlobStore, VaultPaths     │
└───────────────────────────────────────────────────────────┘
```

The flow goes one direction: UI never reaches past the cubit; cubits never
reach past use cases. The router and `AppServices` are the only places that
know about the full dependency graph — they are the composition root.

## Dependency container

[`lib/app/app_scope.dart`](../lib/app/app_scope.dart) defines `AppServices` —
the bag of singletons the app needs at runtime — and `AppScope`, the
`InheritedWidget` that exposes them to the widget tree.

```dart
class AppServices {
  final VaultService vault;
  final VaultPaths paths;
  final LockSettings lockSettings;

  late final DocumentRepository documents = DocumentRepository(vault);
  late final TagRepository tags = TagRepository(vault);
  late final HiddenTagRepository hiddenTags = HiddenTagRepository(vault);
  late final FolderRepository folders = FolderRepository(vault);
  late final OcrService ocr = OcrService();
  late final AutoClassifier classifier = AutoClassifier();
  late final DocumentImportService importer = DocumentImportService(...);
  late final DocumentOpenService opener = DocumentOpenService(...);
  late final ShareService share = ShareService(...);
  late final BackupService backup = BackupService(...);
  late final BiometricService biometrics = BiometricService();
  late final AutoLockController autoLock = AutoLockController(...);
}
```

Most fields are `late final` and lazily instantiated, so adding a new
repository or service is a one-line addition.

`AppScope.of(context)` is called from:

- The router's route builders, when constructing a cubit
- A sheet's `static show(context)` method, before invoking
  `showModalBottomSheet`
- Nowhere else — screens themselves don't reach into `AppScope`

## Routing as the composition root

[`lib/app/router.dart`](../lib/app/router.dart) builds the `GoRouter`. Each
route's `builder` constructs the cubit it needs and wraps the screen in a
`BlocProvider`:

```dart
GoRoute(
  path: AppRoutes.documents,
  builder: (context, _) {
    final s = AppScope.of(context);
    return BlocProvider(
      create: (_) => DocumentsListCubit(
        searchDocuments: SearchDocumentsUseCase(
          documents: s.documents, tags: s.tags, hiddenTags: s.hiddenTags,
        ),
        // ... other use cases
      ),
      child: const DocumentsListScreen(),
    );
  },
),
```

This is verbose, but it's the only place use case wiring happens — and that's
deliberate. Cubits and screens get exactly the use cases they need; everything
else is hidden.

## Vault state drives navigation

[`VaultService`](../lib/features/vault/vault_service.dart) extends
`ChangeNotifier`. It computes its `VaultState` lazily:

```dart
VaultState get state {
  if (!VaultDescriptor.exists(_paths)) return VaultState.uninitialized;
  if (_vaultDb == null || _kek == null) return VaultState.locked;
  return VaultState.unlocked;
}
```

`GoRouter` is configured with `refreshListenable: vault` and a `redirect`
callback that reads `vault.state` and rewrites the route:

| `VaultState` | Effective route |
| --- | --- |
| `uninitialized` | always `/onboarding` |
| `locked` | always `/lock` |
| `unlocked` | `/documents` (and any sub-route under it) |

So when `vault.lock()` runs (via `LockVaultUseCase` in `DocumentsListCubit`),
`notifyListeners()` fires, the redirect re-evaluates, and the user lands on
`/lock` automatically. The cubit doesn't navigate — it just locks the vault.

## A walkthrough: importing a file

This is the spine of the app — encryption, persistence, indexing, UI refresh.

1. **User taps the import FAB.** `_DocumentsListScreenState._import()` opens
   `FilePicker` and packs the result into `List<ImportFileInput>`, then calls
   `cubit.importFiles(inputs)`.
2. **Cubit emits busy.** `DocumentsListCubit.importFiles` sets `busy: true`
   and clears any error/message.
3. **UseCase dispatches.** `ImportFilesUseCase` iterates the inputs and calls
   `DocumentImportService.importBytes` or `.importFile`.
4. **Service does the work.**
   [`DocumentImportService`](../lib/features/documents/document_import_service.dart):
   - resolves MIME type
   - if image, runs OCR via Google ML Kit (`OcrService`)
   - runs the keyword classifier (`AutoClassifier`)
   - generates a fresh DEK (32 random bytes)
   - wraps the DEK under the vault's KEK (AES-GCM)
   - encrypts the file bytes under the DEK (AES-GCM)
   - writes the ciphertext to `blobs/<uuid>.enc` via `BlobStore`
   - inserts the row in `documents` and the FTS row in `documents_fts`
5. **Repository notifies.** `DocumentRepository._notify()` pushes `null` into
   its `Stream<void> changes`.
6. **Cubit refreshes.** The cubit's `_docSub` listener fires `_refreshDocuments`,
   which re-runs `SearchDocumentsUseCase` and emits a new state with the
   fresh document list.
7. **UI rebuilds.** `BlocBuilder<DocumentsListCubit, DocumentsListState>`
   sees the new state, draws the new card, and `BlocListener` shows the
   "Imported N file(s)" snackbar.

If anything in step 4 throws, the service deletes the orphan blob before
re-throwing, the cubit emits `error: ...`, and `BlocListener` shows it as a
snackbar.

## Hard rules

These are load-bearing — breaking them will introduce subtle bugs.

1. **All KEK / DEK / DB access goes through `VaultService`.** Never
   re-derive a key, never open the SQLCipher DB elsewhere. See
   [`security.md`](security.md) for why.
2. **Decrypted plaintext is short-lived.** It exists in memory during
   re-encryption, and in a temp file while the system viewer reads it. The
   temp dir is wiped on `vault.lock()`. Don't introduce caches.
3. **`vault.lock()` must clear `_kek`, `_tagHmacKey`, and close `_vaultDb`.**
   The `state` getter relies on those becoming null. Routing depends on it.
4. **Hidden tags never appear in lists, autocompletes, or counts.** They only
   reveal documents when the exact name is typed into search and matches the
   HMAC. See [`security.md`](security.md#hidden-tags).
5. **Use cases take dependencies via constructor.** No locator, no global. If
   you find yourself calling `AppScope.of(...)` inside a use case, you're in
   the wrong layer.
6. **One screen / one sheet → one cubit.** Don't share cubits across
   navigation surfaces. If two screens need the same data, both subscribe to
   the same repository changes stream — that's what it's for.

## Where things live

```
lib/
  app/
    app.dart            – MaterialApp.router, top-level BlocProvider
    app_scope.dart      – AppServices + AppScope InheritedWidget
    router.dart         – GoRouter config + redirect + per-route BlocProviders
    routes.dart         – path string constants
    theme.dart          – Material 3 theme

  core/
    crypto/             – Kdf, VaultCrypto, Aead, TagHmac
    storage/            – VaultDatabase, BlobStore, VaultPaths

  features/
    onboarding/
      onboarding_screen.dart
      cubit/{onboarding_cubit,onboarding_state}.dart
    vault/
      vault_service.dart, vault_descriptor.dart, lock_screen.dart
      cubit/{vault_cubit,lock_cubit,lock_state}.dart
      usecases/{initialize,unlock,lock}_vault.dart
    documents/
      document.dart, *_repository.dart, *_service.dart
      documents_list_screen.dart, document_detail_screen.dart
      folder_scope.dart
      cubit/{documents_list,document_detail}_cubit.dart  + states
      usecases/*.dart
    folders/
      folder.dart, folder_repository.dart, folder_picker_sheet.dart
      cubit/{folder_picker_cubit,folder_picker_state}.dart
      usecases/*.dart
    tags/                — same shape as folders/
    hidden_tags/         — same shape, plus crypto helpers
    sharing/             — share_service.dart + 2 usecases
    backup/              — backup_service.dart + 2 usecases
    ocr/                 — ocr_service.dart, auto_classifier.dart
    security/            — biometric_service.dart, lock_settings.dart,
                           auto_lock_controller.dart, 4 usecases

  main.dart              – app entry: resolve paths, build AppServices, runApp
```
