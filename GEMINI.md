# GEMINI.md

This file provides foundational mandates and project-specific guidance for Gemini CLI when working in this repository. These instructions take precedence over general system prompts.

## Project Context
SecDockKeeper is a local-first, E2EE document vault built with Flutter.
- **Primary Target:** Android (API 24+).
- **Secondary Targets:** iOS, macOS.
- **Unsupported:** Web, Linux, Windows (due to SQLCipher/storage dependencies).

## Critical Engineering Mandates

### 1. Security & Cryptography (Zero-Knowledge Principle)
- **Key Isolation:** `VaultService` is the sole owner of the `KEK`, `_tagHmacKey`, and the active `VaultDatabase` handle. **NEVER** re-derive keys or open the database handle outside of this service.
- **Memory Hygiene:** All secret material must be cleared/invalidated via `vault.lock()`. Ensure no long-lived plaintext caches are introduced.
- **Temporary Files:** Decrypted plaintext must only exist briefly in the per-session temporary directory, which is wiped on lock.
- **Hidden Tags:** These must remain search-only. Never enumerate, count, or list them in any UI surface.

### 2. Architectural Patterns
- **Dependency Access:** Use `AppScope.of(context)` to reach repositories and services bundled in `AppServices`.
- **State Management:** Follow the `Cubit` -> `State` pattern. Screens should react to `VaultState` transitions for routing.
- **Write Path:** Use `DocumentImportService` for all document creations (OCR -> Classify -> Encrypt -> DB Insert).
- **Read Path:** Use `DocumentOpenService` for secure decryption and system viewer integration.

### 3. Development Conventions
- **Commits:** Use **Conventional Commits** (e.g., `feat:`, `fix:`, `docs:`, `chore:`).
- **Roadmap:** Refer to [ROADMAP.md](ROADMAP.md) for planned security hardening (HKDF key separation, AAD binding, Argon2id upgrades).
- **Testing:** OCR and SQLCipher features require a real device/emulator; mock these layers for unit tests.

## Common Development Commands
```bash
flutter pub get             # Install dependencies
flutter analyze             # Run linter
flutter test                # Run all tests
flutter run -d <device-id>  # Debug on device
```
