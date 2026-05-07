# Testing

The test suite focuses on the **use case layer**. Every use case has a
test file; cubits and widgets do not. This page explains the strategy, the
mocktail patterns we use, and the constraints.

## What's tested

```
test/
├─ features/
│  ├─ backup/usecases/
│  ├─ documents/usecases/
│  ├─ folders/usecases/
│  ├─ hidden_tags/usecases/
│  ├─ security/usecases/
│  ├─ sharing/usecases/
│  ├─ tags/usecases/
│  └─ vault/usecases/
└─ widget_test.dart           ← placeholder, runs to keep the runner happy
```

35 use cases, 35 test files. The structure mirrors `lib/features/*/usecases/`
one-for-one, so finding the test for a given file is mechanical.

## What's *not* tested

- **Cubits.** They're pure dispatch layers over use cases. If the use cases
  are correct, a cubit can only fail in trivial ways (wrong field set,
  forgot to emit). `bloc_test` is a dev dependency for when this changes.
- **Widgets.** No `flutter_test` widget tests beyond the placeholder. The
  screens are heavy on Material 3 visuals that don't lend themselves to
  unit-level testing.
- **Repositories.** They wrap SQLCipher, which doesn't run in pure-Dart
  unit tests — the native plugin needs a real device or emulator.
- **Crypto layer.** `Aead`, `Kdf`, `VaultCrypto` are thin wrappers over
  `package:cryptography`. The library is well-tested upstream; we don't
  duplicate that.
- **Migrations.** `VaultDatabase._onUpgrade` runs against SQLCipher, see
  above. Migration testing is manual on-device.

## Why use cases get the testing focus

1. **They contain the business logic.** Repositories are CRUD; services
   are I/O; cubits are dispatch. The interesting orchestration lives in
   use cases (`SearchDocumentsUseCase`, `BiometricUnlockUseCase`,
   `DeleteDocumentUseCase`, etc.).
2. **They're pure Dart.** No platform plugins, no `BuildContext`, no
   `WidgetsBindingObserver`. They run in the standard Dart VM under the
   normal `flutter test` runner with no extra setup.
3. **They're trivially mockable.** Constructor takes interfaces (well,
   concrete classes mocked via mocktail's `Mock implements`). No
   service-locator means no global state to clean between tests.

## Tools

- **`flutter_test`** — the standard test runner.
- **`mocktail` ^1.0.5** — null-safe mocking, no codegen. Used for every
  mock in the suite.
- **`bloc_test` ^10.0.0** — dev dependency, currently unused. Available
  for future cubit tests.

## Mocktail patterns

### Mocking a service

```dart
import 'package:mocktail/mocktail.dart';
import 'package:secdockeeper/features/vault/vault_service.dart';

class _MockVaultService extends Mock implements VaultService {}

void main() {
  late _MockVaultService vault;
  late InitializeVaultUseCase useCase;

  setUp(() {
    vault = _MockVaultService();
    useCase = InitializeVaultUseCase(vault);
  });
  // ...
}
```

`extends Mock implements VaultService` works even though `VaultService`
extends `ChangeNotifier` — `implements` only requires us to provide the
public surface, and mocktail handles that via `noSuchMethod`.

### Stubbing methods

```dart
when(() => vault.initialize(any())).thenAnswer((_) async {});
when(() => vault.unlock(any())).thenAnswer((_) async => true);
```

For `Future<void>` returns, use `thenAnswer((_) async {})`. For exceptions,
`thenThrow(...)`.

### Stubbing getters

```dart
when(() => vault.blobStore).thenReturn(blobStore);
when(() => repo.changes).thenAnswer((_) => stream);
```

A getter that returns a non-nullable type **must** be stubbed before the
use case calls it — otherwise mocktail returns `null` and the test crashes
with a `TypeError`.

### Verifying calls

```dart
verify(() => vault.initialize('hunter2')).called(1);
verifyNever(() => vault.unlock(any()));
verifyInOrder([
  () => blobStore.delete('uuid-here'),
  () => repo.deleteById(7),
]);
```

`verifyInOrder` is essential for testing order-sensitive orchestrations
like `DeleteDocumentUseCase` (blob-then-row) and `ExportBackupUseCase`
(temp-clear-then-export-then-share).

### Fallback values

When `any()` is used for a parameter type that mocktail can't construct a
default for (custom classes, `File`, `Document`, `BackupArchive`), register
a fake in `setUpAll`:

```dart
class _FakeFile extends Fake implements File {}
class _FakeDocument extends Fake implements Document {}

void main() {
  setUpAll(() {
    registerFallbackValue(_FakeFile());
    registerFallbackValue(_FakeDocument());
  });
  // ...
}
```

Without this, `any()` for a `File` parameter throws
`Bad state: A test tried to use any or captureAny on a parameter of type ...`.

### Named arguments

```dart
when(() => biometrics.authenticate(reason: any(named: 'reason')))
    .thenAnswer((_) async => true);

verify(() => biometrics.authenticate(reason: 'Custom')).called(1);
```

`any(named: '<name>')` is the way to match named args. Plain `any()` only
matches positional.

## Test structure conventions

1. **One `setUp` per test group.** Re-construct mocks fresh for each test
   so leftover stubs don't bleed across cases.
2. **Test names describe the *outcome*, not the method.** "returns
   Cancelled when platform auth is denied" beats "tests authenticate=false
   path".
3. **Group by behaviour, not by code structure.** Most files have a single
   `void main()` with several `test(...)` blocks. `group(...)` is fine if
   there are clearly separate concerns (e.g. happy path vs. error path),
   but don't add it for two tests.
4. **Inline test data.** `Document _doc(int id)` helpers are inline in the
   test file. Don't introduce a shared `test/helpers/factories.dart`
   unless three or more tests would use the same constructor.
5. **No real I/O.** No real filesystem, no real DB, no real `LocalAuth`
   plugin. Every external boundary is mocked.

## Running tests

```bash
flutter test                                   # whole suite
flutter test test/features/vault/              # one feature
flutter test --name "Cancelled when"           # by name match
flutter test --reporter expanded               # verbose output
```

CI-equivalent locally:

```bash
flutter analyze && flutter test
```

Both commands must pass before any PR ships.

## When you change a use case

1. The corresponding test file must be updated in the same commit.
2. If you add a new branch (e.g. a new sealed-class variant in
   `BiometricUnlockResult`), add a test for it. Sealed classes are
   exhaustive in `switch`, so missing branches are caught at compile time
   for the cubits — but not for the test coverage.
3. If you add a new use case, follow the pattern: constructor takes
   dependencies, has a `call(...)` method, has a sibling test file at the
   matching path.

## When mocktail isn't enough

For tests that genuinely need `sqflite_sqlcipher` or the OCR plugin, the
standard `flutter test` runner won't work — those plugins require a real
platform. Three options, ordered by preference:

1. **Don't.** If the logic can be tested with the repository mocked out,
   test it that way. The point of the use case layer is that you almost
   never have to.
2. **`flutter test integration_test/`** with a real device or emulator.
   No integration tests exist yet; if you add the first one, document the
   harness in this file.
3. **Manual on-device verification.** Acceptable for one-off changes (a
   schema migration, a viewer integration). Document the steps in the PR
   description.
