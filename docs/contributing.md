# Contributing

Recipes for the most common changes. Each recipe assumes you've read
[`architecture.md`](architecture.md) and [`state-management.md`](state-management.md).

## Setup

```bash
flutter pub get
flutter analyze && flutter test       # baseline must be clean
```

CI-equivalent gate (must pass before any PR):

```bash
flutter analyze && flutter test
```

The Android APK build is the canonical platform check; a green Android
build is the bar:

```bash
flutter build apk --debug --target-platform android-arm64 --split-per-abi
```

## Adding a new use case

1. Create the file under `lib/features/<feature>/usecases/<name>.dart`.
2. Single class, constructor takes dependencies, single public `call`
   method (named params if there's more than one):

   ```dart
   import '../<repo>.dart';

   class <Name>UseCase {
     <Name>UseCase(this._repo);
     final <Repo> _repo;

     Future<<Return>> call({required <X> x}) => _repo.<method>(x);
   }
   ```

3. Create the matching test file at
   `test/features/<feature>/usecases/<name>_test.dart`. Mock the repository
   with mocktail (`extends Mock implements <Repo>`). At minimum, verify the
   call is forwarded with the expected arguments.
4. Wire it in the cubit that needs it: add a constructor parameter, store
   on a `final` field, call from the relevant action.
5. Wire it in [`lib/app/router.dart`](../lib/app/router.dart) — find the
   `BlocProvider` for the cubit and add `<name>: <Name>UseCase(s.<repo>)`
   to the cubit constructor call.
6. Add an entry to [`usecases.md`](usecases.md) in the right table.
7. Run `flutter analyze && flutter test`. Both must pass.

## Adding a new screen

1. Pick a path. Top-level (`/<thing>`) for a screen reachable from the
   gate, or a child of `/documents` for screens reached after unlock.
   Add the constant to [`lib/app/routes.dart`](../lib/app/routes.dart).
2. Create the directory: `lib/features/<feature>/`.
3. Create the cubit:
   - `lib/features/<feature>/cubit/<feature>_cubit.dart`
   - `lib/features/<feature>/cubit/<feature>_state.dart`
   - Follow the conventions in
     [`state-management.md`](state-management.md#cubit-conventions): take
     use cases via constructor, subscribe to `Stream<void> changes` if you
     need reactivity, cancel subscriptions in `close()`, guard
     post-await emits with `if (!isClosed)`.
4. Create the screen widget: `lib/features/<feature>/<feature>_screen.dart`.
   Use `BlocBuilder` / `BlocConsumer` to read state, `context.read<Cubit>()`
   to dispatch.
5. Wire the route in [`lib/app/router.dart`](../lib/app/router.dart):

   ```dart
   GoRoute(
     path: AppRoutes.<thing>,
     builder: (context, _) {
       final s = AppScope.of(context);
       return BlocProvider(
         create: (_) => <Feature>Cubit(
           // use cases pulled from s
         ),
         child: const <Feature>Screen(),
       );
     },
   ),
   ```

6. Update the redirect in `router.dart` only if the new route should only
   be reachable in a specific `VaultState`. For most screens (under
   `/documents`), no redirect change is needed.
7. Use `context.push(AppRoutes.<thing>)` from wherever you trigger
   navigation to it.

If the screen warrants a feature walkthrough, add a section to
[`features.md`](features.md).

## Adding a new sheet

Sheets follow the same pattern as screens but they're not routed.

1. Build the sheet widget under `lib/features/<feature>/<feature>_sheet.dart`.
2. Build the cubit and state next to it under `cubit/`.
3. Add a `static Future<void> show(BuildContext context, ...)` method on
   the sheet widget. This is the *only* place its cubit is constructed:

   ```dart
   static Future<void> show(BuildContext context, int documentId) {
     final services = AppScope.of(context);
     return showModalBottomSheet(
       context: context,
       isScrollControlled: true,
       builder: (_) => BlocProvider(
         create: (_) => <Feature>Cubit(
           // ... use cases from services
         ),
         child: const <Feature>Sheet(),
       ),
     );
   }
   ```

4. Call `<Feature>Sheet.show(context, ...)` from wherever the sheet is
   opened. Don't use `showModalBottomSheet` directly elsewhere — go
   through `show` so the cubit is always constructed correctly.

## Adding a database migration

The schema is at version 3. To bump to 4:

1. Open [`lib/core/storage/vault_database.dart`](../lib/core/storage/vault_database.dart).
2. Bump `version: 3` to `version: 4` in `VaultDatabase.open`.
3. Add `if (oldVersion < 4) { ... }` inside `_onUpgrade`.
4. Use `db.batch()` for multi-statement migrations:

   ```dart
   if (oldVersion < 4) {
     final batch = db.batch();
     batch.execute('ALTER TABLE documents ADD COLUMN ...');
     batch.execute('CREATE INDEX ...');
     await batch.commit(noResult: true);
   }
   ```

5. **If you change the FTS5 columns**, drop and rebuild — see the v3 block
   for the pattern. SQLite's FTS5 doesn't support `ALTER TABLE` for virtual
   tables.
6. Update the schema reference in [`storage.md`](storage.md).
7. Test on a device with an existing v3 vault: build the app *without*
   uninstalling, open the vault, verify documents/folders/tags are intact.
   The unit test suite cannot validate migrations.

If your migration touches any column whose mapping lives in `Document.fromRow`
(or similar `fromRow` constructors in models), update those too.

## Adding a new repository field on `documents`

This is the messiest schema change because it touches the FTS index, the
import flow, the `fromRow` mapper, and several use cases. Follow the order:

1. Add the column with a migration (as above).
2. Add the field to [`Document`](../lib/features/documents/document.dart).
   Update `fromRow`. If the field can be null in old rows, make it nullable
   here too.
3. Update [`DocumentRepository.create`](../lib/features/documents/document_repository.dart)
   — add the column to the insert map.
4. Update [`DocumentImportService`](../lib/features/documents/document_import_service.dart)
   to compute and pass the new value.
5. If the field should be searchable, change the FTS schema (drop +
   rebuild) and update `documents_fts` insertions.
6. Surface the field in `DocumentsListState`, `DocumentDetailState`, the
   list card, the detail meta block — wherever it should appear.
7. Tests: any use case that constructs a `Document` will need updating
   if the field is required. Most existing tests use a small `_doc()`
   helper at the top of the file — adjust there.

## Working with hidden tags

Anything touching hidden tags should be reviewed against the invariants in
[`security.md`](security.md#invariants-for-hidden-tags). The short version:

- They must not appear in any list, autocomplete, or count.
- The HMAC key is HKDF-derived from the KEK; don't re-derive it elsewhere.
- A search-bar query that exactly matches a hidden tag name reveals
  documents — that's the only sanctioned reveal path.

If a feature you're building seems to require enumerating hidden tags
across documents, the answer is almost certainly "don't build it that
way". Talk through the design before coding.

## Running on-device

```bash
flutter devices                                      # list connected devices
flutter run -d <device-id>                           # run with hot reload
flutter run -d <device-id> --release                 # release perf
```

OCR and SQLCipher both require a real device or emulator. The pure-Dart
`flutter test` runner can't exercise either.

## Things that often break

1. **`if (!isClosed)` guards**. Forgetting them in async cubit code
   manifests as `Bad state: Cannot emit new states after calling close`
   in the console after a screen pop.
2. **Stream subscriptions not cancelled in `close()`**. The cubit lives
   forever and keeps receiving repository changes from the next session.
3. **Use case constructed with `services.<x>` getter that doesn't exist**.
   The router builds get awkward fast; double-check the field name on
   `AppServices`.
4. **`context.read<Cubit>()` after the bloc has been disposed**. Happens
   in `BlocListener` callbacks if you stash `context` and use it after
   the screen pops. Read the cubit eagerly: `final cubit =
   context.read<Cubit>(); ...; cubit.<method>(...)`.
5. **`LockState` collision**. Flutter exports a `LockState` enum from
   `material.dart`. If you name a state class `LockState`, Dart complains
   about ambiguous imports. Prefix with the feature, e.g. `VaultLockState`.

## Things to avoid (recap)

- Don't bypass `VaultService` for crypto, key derivation, or DB access.
- Don't store decrypted plaintext beyond the immediate operation.
- Don't add use cases that require `BuildContext`.
- Don't share cubits across screens.
- Don't enumerate hidden tags.
- Don't call `notifyListeners` directly on `VaultService` — use
  `notifyExternalChange()` if you genuinely need to nudge the router from
  outside the standard `initialize`/`unlock`/`lock` flow.
- Don't catch and silently swallow decryption errors. They mean either
  tampering or wrong-key, and they should propagate to the user.

## Where to ask

Code review is the right place to surface design questions. The doc files
in this folder should be the source of truth — if a piece of architecture
isn't covered, that's a documentation bug worth filing alongside whatever
PR you're working on.
