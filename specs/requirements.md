<!--
  scope: cross-cutting only

  Per-FR detail lives in `specs/frs/<id>.md` exclusively (written by
  /dev-process-toolkit:spec-write). Do NOT add `### FR-N: ...` heading blocks
  here. This project runs in `mode: none`, so FR files and AC IDs key on the
  short-ULID tail (`AC-<short-ULID>.<N>`).
-->

# Requirements

## 1. Overview

SecDockKeeper is a local-first, end-to-end encrypted document vault for people who want to keep identity documents, contracts, scans and notes on their phone without trusting a cloud service. Everything is encrypted on device under a key derived from a single master password; nothing leaves the device unless the user explicitly exports or shares it. Android is the primary target; iOS and macOS build. Feature-level detail of what already ships is in `docs/features.md`.

## 2. Functional Requirements (cross-cutting only)

- **Vault gate:** every screen that shows user data is reachable only while the vault is unlocked. Locking (manual, auto-lock on background, panic action) clears all key material and routes back to the lock screen.
- **Single write/read path:** documents are written only through the import use cases (OCR → classify → DEK → wrap → encrypt blob → insert row) and read only through the open use case. See `docs/usecases.md`.
- **Hidden tags are search-only:** they never appear in any list, autocomplete or count surface.
- **Export is explicit:** sharing and backup are user-initiated, and shared packages split ciphertext (`.sdkblob`) from the wrapping key (`.sdkkey.json`).

## 3. Non-Functional Requirements

### NFR-1: Performance
- Unlock (Argon2id with the active profile) completes in a time the user accepts on a mid-range Android device; changing `KdfParams.defaultParams` must be weighed against unlock latency.
- Vault list and search stay responsive with the full FTS5 index on device.

### NFR-2: Security
- Key hierarchy, threat model and lifecycle of secret material are defined in `docs/security.md` and are binding for every FR.
- Plaintext is short-lived: in memory during import re-encryption and in a temp file while a system viewer reads it; the temp directory is wiped on lock.
- No key material in backups, logs, analytics or crash reports. `FLAG_SECURE` stays on for Android.

### NFR-3: Availability
- Fully offline: no feature may require network access to read or write the vault.
- Schema migrations (`VaultDatabase._onUpgrade`) never lose data; they are verified on device because SQLCipher does not run in unit tests.

## 4. Edge Cases

<!-- Each entry: scenario, expected behavior, test reference -->

## Security / Abuse Cases

| Attacker Goal | Attack Vector | Mitigation |
|--------------|---------------|------------|
| Read documents from a stolen device | Copy app-support directory and attack offline | SQLCipher DB + AES-GCM blobs under an Argon2id-derived KEK; `vault.json` holds only salt + params |
| Guess the master password on a recovered device | Repeated unlock attempts | Panic mode: escalating lockout or wipe on the 3rd failure; biometric suppressed after a wrong password |
| Prove hidden content exists | Browse UI lists, counts, autocomplete | Hidden tags stored as HMAC only and surfaced solely on exact-name search |
| Obtain a shared document in transit | Intercept one delivery channel | Ciphertext and key file delivered separately; either alone is useless |

## 5. Out of Scope

- Cloud sync or any server-side component
- Web, Linux and Windows builds (the storage layer depends on SQLCipher + `path_provider`)

## 6. Traceability Matrix

| Requirement | Implementation | Tests |
|-------------|---------------|-------|
