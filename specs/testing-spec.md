# Testing Specification

## 1. Test Framework
- **Runner:** `flutter_test` (`flutter test`)
- **Mocking:** `mocktail` 1.0.5 (`class MockX extends Mock implements X`), no codegen
- **Cubits:** `bloc_test` 10.0.0 available
- **Coverage:** `flutter test --coverage` (lcov) when needed; no CI threshold yet

## 2. Test Structure

**Layout policy: `tests/-mirror`** — declared in CLAUDE.md `## Testing Conventions`. `test/` mirrors `lib/` one-for-one:

```
lib/features/vault/usecases/unlock_vault.dart
test/features/vault/usecases/unlock_vault_test.dart
```

## 3. Conventions

### Naming
- Files: `*_test.dart`
- Names: describe the expected behavior (`'returns wrongPassword and records a failed attempt'`)

### What to Test
- Every use case: happy path, error paths, lock/panic side effects, and that secrets are not leaked through return values
- Cubit state transitions with `bloc_test` when a cubit gains logic beyond dispatch

### What NOT to Test
- `package:cryptography` internals, SQLCipher, ML Kit and other native plugins (verified on device)
- Generated code and Material visuals

## 4. Coverage Targets
| Layer   | Target | Minimum |
|---------|--------|---------|
| Use cases | every use case has a test file | every new use case ships with tests |
| Overall | not enforced | — |

## 5. Test Data
Fakes and mocks are built inline per test with mocktail; no shared fixtures or real vault files (vault test data is git-ignored).
