# State management

The app uses `flutter_bloc`'s [`Cubit`](https://pub.dev/packages/flutter_bloc)
for screen-level state. There is no `Bloc` (event-driven) usage, no
`StreamProvider`, no `Provider`, no `Riverpod`. Every screen and every sheet
has exactly one cubit.

## Cubit inventory

| Surface | Cubit | State class |
| --- | --- | --- |
| App-global vault state mirror | `VaultCubit` | `VaultState` (enum, owned by `VaultService`) |
| Onboarding screen | `OnboardingCubit` | `OnboardingState` |
| Lock screen | `LockCubit` | `VaultLockState` |
| Documents list screen | `DocumentsListCubit` | `DocumentsListState` |
| Document detail screen | `DocumentDetailCubit` | `DocumentDetailState` |
| Folder picker sheet | `FolderPickerCubit` | `FolderPickerState` |
| Tag picker sheet | `TagPickerCubit` | `TagPickerState` |
| Hidden tags sheet | `HiddenTagsCubit` | `HiddenTagsState` |

`VaultLockState` is named that way (rather than `LockState`) because Flutter
exports a `LockState` enum from `material.dart` that would otherwise shadow
the cubit's state class. If you add a cubit and Dart complains about an
ambiguous import, prefix the state name with the feature.

## State classes

States are plain Dart classes with `final` fields, a `copyWith` method, and
manual `==` / `hashCode` overrides. Pattern:

```dart
class DocumentsListState {
  const DocumentsListState({
    this.documents = const [],
    this.busy = false,
    this.error,
    // ...
  });

  final List<Document> documents;
  final bool busy;
  final String? error;
  // ...

  DocumentsListState copyWith({
    List<Document>? documents,
    bool? busy,
    String? error,
    bool clearError = false,
    // ...
  }) { ... }
}
```

Conventions:

1. **`copyWith` uses sentinels for nullable clearing.** Nullable fields can't
   be set to `null` via the standard `field ?? this.field` idiom — `null`
   means "no change". Pass `clearError: true` to set `error` back to `null`.
2. **Collections are passed as the new value, not appended.** A cubit should
   compute the next list and emit it whole. No "addOne / removeOne" mutations
   on the state.
3. **States holding collections may not implement `==` exhaustively.**
   `DocumentsListState` and similar collection-heavy states use identity
   equality for collections, so every emit is "different" by `==`. That's
   fine — `BlocBuilder` rebuilds, which is what we want when the list
   changed; if you need to filter rebuilds use `buildWhen`. Simpler states
   (`OnboardingState`, `VaultLockState`) override `==` properly.

## Cubit conventions

### Constructor takes use cases

```dart
class DocumentsListCubit extends Cubit<DocumentsListState> {
  DocumentsListCubit({
    required SearchDocumentsUseCase searchDocuments,
    required ListFoldersUseCase listFolders,
    // ...
  }) : _searchDocuments = searchDocuments,
       _listFolders = listFolders,
       // ...
       super(const DocumentsListState()) {
    _docSub = watchDocumentChanges().listen((_) => _refreshDocuments());
    _refreshDocuments();
  }
}
```

No service-locator, no `BuildContext`, no global. The router constructs the
use cases and passes them in. The cubit becomes trivially testable.

### Reactive subscriptions

Cubits that show a live list subscribe to the relevant repository's
`Stream<void> changes` in the constructor. The pattern:

```dart
late final StreamSubscription<void> _docSub;

// in constructor:
_docSub = watchDocumentChanges().listen((_) => _refreshDocuments());
_refreshDocuments();

// in close():
@override
Future<void> close() async {
  await _docSub.cancel();
  return super.close();
}
```

Always cancel the subscription in `close()`. Otherwise the cubit leaks every
time a screen is popped.

`watchDocumentChanges` etc. are use cases that just expose the underlying
repo stream — they exist to keep the dependency arrow consistent
(cubit → use case → repo). They're trivial but uniform.

### `isClosed` guards before emit

Async work might complete after the screen is gone (route popped, user
backgrounded the app). Always guard the post-await emit:

```dart
Future<void> _refreshDocuments() async {
  final docs = await _searchDocuments(...);
  if (!isClosed) {
    emit(state.copyWith(documents: docs, loadingDocuments: false));
  }
}
```

Skipping the guard manifests as `Bad state: Cannot emit new states after
calling close` in the console.

### One-shot signals: error, message, popRequested

For transient effects — show a snackbar, close the screen — the state has a
nullable field. The cubit emits the field set, the UI's `BlocListener`
reacts, and (if needed) the cubit emits again with the field cleared.

| Signal | Field | Used by |
| --- | --- | --- |
| Error to show | `error: String?` | All cubits |
| Snackbar message | `message: String?` | `DocumentsListCubit` |
| Pop the screen | `popRequested: bool` | `DocumentDetailCubit`, `FolderPickerCubit`, `OnboardingCubit` |
| Show biometric dialog | `askBiometric: bool` | `OnboardingCubit` |

The screen uses `BlocConsumer` (or a separate `BlocListener`) with
`listenWhen` to fire the side effect once:

```dart
BlocConsumer<DocumentDetailCubit, DocumentDetailState>(
  listenWhen: (prev, curr) => prev.popRequested != curr.popRequested,
  listener: (context, state) {
    if (state.popRequested) context.pop();
  },
  builder: (context, state) { ... },
)
```

## Cubits don't navigate

A cubit never calls `context.go` or `context.pop`. The screen's
`BlocListener` reads the signal and calls the navigation API. This keeps
the cubit free of `BuildContext` (so it's testable in pure Dart) and keeps
navigation responsibilities on the widget side.

The exception is `VaultCubit`, which doesn't navigate either — it just
mirrors `VaultService.state`. Routing reacts via the `refreshListenable`
hooked directly to `VaultService`.

## State diagrams

### `OnboardingCubit`

```
                  ┌──────────────────────┐
   create(pwd) ──▶│ busy=true            │
                  └─────┬────────────────┘
                        │ check biometric availability
            ┌───────────┴───────────┐
   not avail│                       │ available
            ▼                       ▼
   call initializeVault     askBiometric=true
   (vault state -> unlocked)  (waits for resolveBiometric)
            │                       │
            │                resolveBiometric(accepted)
            │                       │ initializeVault
            │                       │ (+ enableBiometrics if accepted)
            │                       │
            ▼                       ▼
       (router redirects to /documents — cubit closes)
```

### `LockCubit`

```
   init() ──▶ check IsBiometricUnlockReady
              │
              ├── if ready → tryBiometric() automatically
              │
              └── busy=true; submit(pwd) or tryBiometric()
                                              │
                          ┌───────────────────┼─────────────────┐
                  success │             cancelled │   error   │
                          ▼                       ▼           ▼
              (vault unlocked → router    busy=false   busy=false
               redirects → cubit closes)               error="..."
```

### `DocumentsListCubit`

```
  constructor:
    subscribe to documents.changes  ─▶ _refreshDocuments
    subscribe to folders.changes    ─▶ _refreshFolders
    initial _refreshDocuments + _refreshFolders + _loadAllTags

  user actions (setQuery, setFolderScope, toggleTagFilter, ...):
    update state.<filter>          ─▶ _refreshDocuments

  one-shot ops (importFiles, exportBackup, lock):
    busy=true → run use case → emit busy=false + (message | error)
                              │
                              ▼ (changes stream fires anyway)
                          _refreshDocuments runs
```

## bloc_test for cubits (not done in this repo)

Cubit tests aren't part of the current test suite — only use cases are
tested. If you decide to add them:

- Use `bloc_test` (already a dev dependency) and its `blocTest` matcher.
- Construct the cubit with stubbed use cases (mocktail). Don't reach into
  real repositories.
- Stream-driven cubits need a `late final StreamController<void>` so the
  test can pump events.

## Things to avoid

- **Don't `setState` in a screen for data that belongs in the cubit.**
  Search controller, password visibility toggle, and similar UI-only state
  stay in the screen. Document list, busy flag, error text go in the cubit.
- **Don't share cubits across screens.** Use `BlocProvider` per route. If
  two screens need the same data, both subscribe to the same repository
  changes stream — that's free.
- **Don't emit inside a constructor synchronously after `super`.** It works,
  but the initial state is more readable when initial values live in the
  state class's defaults and async kicks load it after.
- **Don't pass the password through state.** `OnboardingCubit` holds it on
  a private field (`_pendingPassword`) when needed, never in
  `OnboardingState`.
