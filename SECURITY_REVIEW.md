# SecDockKeeper — Security & Refactoring Review

**Date:** 2026-06-20
**Scope:** Static review of the Dart/Flutter source (`lib/`), Android platform config, and dependency manifest. No dynamic testing or device run was performed (the OCR/SQLCipher stack needs a real device).
**Reviewer:** Automated code audit, cross-checked against current cryptographic guidance.

---

## 1. Executive summary

SecDockKeeper has a fundamentally sound design: per-document DEKs wrapped under an Argon2id-derived KEK, SQLCipher for metadata, `FLAG_SECURE` set, `allowBackup="false"`, a KDF-parameter floor that rejects downgraded vault descriptors, constant-time password comparison, and HKDF-separated hidden-tag HMAC keys. The crypto primitives themselves (AES-256-GCM, Argon2id, HKDF-SHA256, HMAC-SHA256) are the right choices.

The issues below are mostly about **how the key material is handled at the edges** — biometric storage, temp-file plaintext, key-rotation atomicity, and a native-crypto backend that is shipped but never switched on — rather than broken primitives. None is a remote-exploitable hole; the realistic threat model is **device theft, a rooted/backed-up device, or a maliciously crafted import/share file**.

Severity counts: **High 3 · Medium 5 · Low/Hardening 6**, plus several refactoring items.

---

## 2. Security findings

### HIGH

#### H-1 — Biometric unlock stores the raw master password, not bound to a biometric-gated key
`lib/features/security/lock_settings.dart:112` (`enableBiometric`) writes the **plaintext master password** into `flutter_secure_storage`. `BiometricUnlockUseCase` (`lib/features/security/usecases/biometric_unlock.dart:51-58`) does a *separate* `authenticate()` call and, on success, reads that stored password back and unlocks.

The biometric check and the stored secret are not cryptographically linked. The `FlutterSecureStorage` instance configures only `iOptions` (iOS) and **never sets `AndroidOptions`** (confirmed: no `AndroidOptions`/`encryptedSharedPreferences`/`.biometric()` anywhere in `lib/`). So on Android the password sits in the plugin's default keystore-wrapped store, but the Keystore key is **not** created with `setUserAuthenticationRequired(true)`. Consequences:

- On a rooted device or via an extraction/backup of app data, the master password — which is full-vault access — is recoverable **without** passing the fingerprint/face prompt.
- Adding a new fingerprint to the device does not invalidate the stored secret.

The biometric is effectively a soft UI gate in front of a recoverable plaintext credential. This matches the documented Android Keystore caveat that data is only protected when the key is generated with user-authentication binding ([flutter_secure_storage docs](https://pub.dev/packages/flutter_secure_storage), [Ostorlab biometric guidance](https://blog.ostorlab.co/secure-mobile-biometric-authentication.html)).

**Fix:** store the secret behind a Keystore key created with `setUserAuthenticationRequired(true)` (use `flutter_secure_storage`'s `AndroidOptions(... )` with biometric binding, or migrate this one secret to `biometric_storage`). Prefer storing a *wrapped KEK* rather than the password itself.

#### H-2 — Path traversal when opening a document: attacker-controlled `originalName` written into a temp path
`DocumentOpenService.decryptToTempFile` (`lib/features/documents/document_open_service.dart:49-57`) builds the temp file path with `p.join(viewDir.path, document.originalName)` and writes decrypted plaintext there. `originalName` is **not sanitised** and can be attacker-controlled: `ShareService.importPackage` (`lib/features/sharing/share_service.dart:82`) takes `original_name` straight from the imported `.sdkkey.json` and `DocumentImportService.importBytes` stores it verbatim. A crafted share package with `original_name` like `../../databases/vault.db` (or any `../` sequence) causes the decrypted plaintext write to **escape `sdk_view`** and can clobber files inside the app sandbox (including vault blobs/DB).

**Fix:** sanitise to a basename and strip path separators before joining (`p.basename(...)`, reject `..`), or write to a randomly named temp file and pass a display name separately. Apply the same basename rule on import.

#### H-3 — Native crypto backend is shipped but never enabled → Argon2id runs pure-Dart on the UI isolate
`cryptography_flutter` is a dependency, but `FlutterCryptography.enable()` is **never called** (confirmed: no reference in `lib/`, including `main.dart`). Without it, `Kdf.deriveKek` (`lib/core/crypto/kdf.dart`) and all AES-GCM run in the package's pure-Dart fallback **on the main isolate**. With the actual default of `m=64 MiB, t=3` (`KdfParams.defaultParams`), unlock will:

- block the UI thread / jank or ANR during every unlock and key rotation, and
- be materially slower than the native path, which in practice pushes developers to *lower* the cost factor — weakening the KDF.

This is both a robustness/UX defect and an indirect security risk (DoS on unlock, pressure to weaken Argon2). It is classed High because it touches the core unlock path and the unused dependency hides the problem.

**Fix:** call `FlutterCryptography.enable()` at startup in `main()`, and/or run `deriveKek` in a background isolate (`compute`). Verify on-device unlock latency after enabling.

### MEDIUM

#### M-1 — No key separation between DEK-wrapping and the SQLCipher passphrase
`VaultService._kekToDbPassword` (`lib/features/vault/vault_service.dart:189-192`) uses `base64(KEK)` directly as the SQLCipher password, and the **same KEK** wraps every DEK (`VaultCrypto.wrapDek`). One secret serves two cryptographic roles. The project already does the right thing for the tag HMAC (HKDF-derived in `tag_hmac.dart`); the DB password should be derived the same way.

**Fix:** `dbKey = HKDF(KEK, info="secdockeeper:db-key:v1")`, keep the bare KEK only for DEK wrapping. (Migration needed — see plan.)

#### M-2 — AEAD has no associated data, so wrapped DEKs / blobs aren't bound to their row
The `aad` parameter is plumbed through `Aead`/`VaultCrypto` (`lib/core/crypto/aead.dart:28,50`, `vault_crypto.dart:55,63`) but **every call passes empty AAD**. A wrapped DEK or file blob is not bound to the document it belongs to. An attacker with DB write access (e.g. a tampered restored backup) can **swap blobs or wrapped-DEK rows between documents** and the crypto layer will not detect it — a confused-deputy / integrity gap.

**Fix:** bind each ciphertext to a stable identity by passing `aad = utf8.encode(uuid)` (or the row id) on both seal and open for DEK wrapping and blob encryption.

#### M-3 — Key rotation is not atomic across the DB re-key and the DEK re-wrap
`RotateVaultKeyUseCase.call` (`lib/features/vault/usecases/rotate_vault_key.dart`) commits the transaction that re-wraps all DEKs under `newKek` (step 5) and *then* runs `PRAGMA rekey` (step 6) and saves the new descriptor (step 7). A crash between the committed transaction and the rekey leaves: DB still openable with the **old** password, but DEKs wrapped under the **new** KEK. The recovery path in `VaultService.unlock` (step 2, backup descriptor) will then open the DB with the old KEK but be **unable to unwrap any DEK** — documents become undecryptable. The descriptor backup protects the *passphrase*, not the re-wrapped DEK state.

**Fix:** make the re-wrap reversible or idempotent — e.g. store both old+new wrapped DEKs until rekey confirms, or re-wrap *after* a successful rekey, or detect partial state on unlock and roll the DEK re-wrap back using the backup. At minimum, document and test the crash windows.

#### M-4 — Plaintext / key material left in temp directories
- `ShareService.exportDocument` writes the decrypted plaintext (`.sdkblob`) **and the raw DEK** (`.sdkkey.json`, `lib/features/sharing/share_service.dart:45-56`) into `sdk_share/<uuid>/` and never deletes them. `DocumentOpenService.deleteAllTemp` only clears `sdk_view` — not `sdk_share`.
- `decryptToTempFile` writes full plaintext into `sdk_view` for the system viewer; cleanup depends on `deleteAllTemp` being called on lock.

The export key file is effectively a plaintext key sitting in the temp dir for the lifetime of the temp cache.

**Fix:** delete share/view temp artifacts promptly (after the share sheet returns / on lock), and include `sdk_share` and `ocr_scratch` in the wipe. Consider an explicit "shred temp on lock" routine wired into `VaultService.lock()`.

#### M-5 — `PRAGMA rekey` built by string interpolation
`VaultDatabase.rekey` (`lib/core/storage/vault_database.dart:129`) does `rawQuery("PRAGMA rekey = '$newPassword'")`. Today `newPassword` is always base64 (no quote characters), so it is safe **by accident**. PRAGMA can't take bind parameters, but this is fragile: any future change that lets a non-base64 string reach this path becomes a SQL-injection / silent-corruption bug.

**Fix:** assert/validate the password is strict base64 before interpolation, or use the SQLCipher key-as-blob hex form (`PRAGMA rekey = "x'<hex>'"`) with a validated hex string.

### LOW / Hardening

- **L-1 — No memory zeroisation.** KEK/DEK bytes are extracted into `Uint8List`/`List<int>` and the master password is a Dart `String` (immutable, un-wipeable). `SecretKey.destroy()` is never called. Secrets linger until GC. Mitigate by minimising copies, calling `destroy()` where the API allows, and avoiding holding the password as a long-lived `String`.
- **L-2 — AES-GCM random 96-bit nonces under a long-lived KEK.** The KEK encrypts every wrapped DEK and every hidden-tag name. NIST guidance limits a key to ~2³² messages with random 96-bit nonces to keep collision probability < 2⁻³² ([Neil Madden](https://neilmadden.blog/2024/05/23/galois-counter-mode-and-random-nonces/), [Soatok](https://soatok.blog/2024/07/01/blowing-out-the-candles-on-the-birthday-bound/)). A personal vault is realistically far below this, so the risk is theoretical — but H-3's AAD fix and per-document DEKs (each used once) already bound most of it. Worth a documented assumption rather than code change.
- **L-3 — `_ensureNotesStorage` silently drops the notes table on schema drift** (`lib/core/storage/vault_database.dart:69-83`). It logs a warning and `DROP TABLE notes`, which is irrecoverable user data loss. Acceptable only because the per-row crypto material would be unusable, but it should surface to the user, not happen silently.
- **L-4 — Argon2 cost vs. UX.** With native crypto enabled (H-3), confirm unlock latency is acceptable; otherwise the `standard`/`hardened` presets are well chosen and the floor check is good.
- **L-5 — `randomBytes` fills byte-by-byte** via `Random.secure()` (`kdf.dart:109-115`). Correct (CSPRNG) but inefficient; a single `nextInt`-per-byte loop is fine for 16–32 byte salts/keys.
- **L-6 — Documentation drift in `CLAUDE.md`.** It states "There is no `go_router`/named-route system … navigation is plain `Navigator.push`" and "default `m=19 MiB, t=2`". The code actually uses `MaterialApp.router` + `GoRouter` (`lib/app/router.dart`, used by multiple screens) and `KdfParams.defaultParams` is `m=64 MiB, t=3`. Stale docs mislead future security reasoning — update them.

---

## 3. Refactoring opportunities

- **Consolidate the `notes` table DDL.** The schema is defined in *three* places — `_onCreate`, `_onUpgrade(<4)`, and `_ensureNotesStorage` (`vault_database.dart`). Triplicated DDL is a drift hazard; extract one `const _createNotesSql` (and FTS) used by all paths.
- **Stop passing `VaultService` into every repository.** Repositories reach into `_vault.db`/`_vault.crypto` directly, coupling all data access to the whole service. Injecting just the `Database`/`VaultCrypto`/`TagHmac` they need would shrink the blast radius and make the repositories unit-testable without a full vault.
- **`VaultDatabase.fromRaw(db).rekey(...)`** in the rotation use case wraps the live handle in a throwaway `VaultDatabase` just to call `rekey` — move `rekey` to operate on the already-open handle the service owns, or expose it through `VaultService`.
- **Centralise temp-dir management.** `sdk_view`, `sdk_share`, `ocr_scratch`, and backup temp dirs are created and (inconsistently) cleaned in three services. A single `TempVault` helper with a `wipeAll()` wired into `VaultService.lock()` would close M-2/M-4 gaps and remove duplication.
- **Reconcile docs and remove dead abstractions.** Confirm whether the old `Navigator.push` description in `CLAUDE.md` reflects leftover code paths; align on `go_router` everywhere or document the split.
- **Pass-through use-case wrappers** (e.g. `RestoreBackupUseCase`, `ImportSharedPackageUseCase`) are one-line delegations. Fine as a convention, but if they never add logic, consider whether the indirection earns its keep.

---

## 4. Prioritised remediation plan

### Phase 0 — Quick wins (low risk, no migration)
1. **H-3:** call `FlutterCryptography.enable()` in `main()`; measure unlock latency; move `deriveKek` to a background isolate if still janky.
2. **H-2:** sanitise `originalName` → basename + reject `..`/separators in `decryptToTempFile` and on import. Add a unit test with a `../` payload.
3. **M-4:** extend temp cleanup to `sdk_share` + `ocr_scratch`; delete share artifacts after the share sheet returns; call a `wipeTemp()` from `VaultService.lock()`.
4. **M-5:** validate base64 before `PRAGMA rekey` interpolation (cheap guard).
5. **L-6:** update `CLAUDE.md` (go_router, real KDF defaults).

### Phase 1 — Biometric hardening (H-1)
6. Configure `AndroidOptions` with a user-authentication-bound Keystore key (or migrate the single secret to `biometric_storage`). Store a wrapped KEK rather than the raw password. Invalidate on biometric enrolment change. Add an on-device test.

### Phase 2 — Crypto integrity, needs migration & tests
7. **M-2:** thread `aad = uuid` through DEK-wrap and blob encrypt/decrypt. Requires a vault schema/format version bump and a re-encrypt-on-open or one-shot migration; gate behind a descriptor version.
8. **M-1:** HKDF-derive the SQLCipher passphrase from the KEK. This is a `PRAGMA rekey` migration on existing vaults — sequence it carefully with M-3.
9. **M-3:** make key rotation crash-safe (re-wrap after successful rekey, or keep old+new wrapped DEKs until confirmed; detect/repair partial state on unlock). Add explicit crash-window tests.

### Phase 3 — Hardening & cleanup
10. **L-1:** minimise secret copies, call `SecretKey.destroy()` where possible, shorten master-password `String` lifetime.
11. **L-3:** surface notes-table drops to the user instead of silent drop.
12. Refactors in §3 (notes DDL consolidation, temp-dir helper, repository dependency narrowing).

### Testing posture
- The crypto layer (`core/crypto/`), descriptor floor checks, FTS query escaping, zip-slip guard, and the new path-traversal guard are all pure-Dart and should get unit tests.
- Rotation atomicity, biometric binding, and native-crypto enablement need on-device/emulator integration tests.

---

## 5. What's already done well (keep it)

- KDF parameter floor rejects downgraded `vault.json` (`kdf.dart:48-59`).
- Constant-time password comparison (`vault_service.dart:147-154`).
- HKDF-separated hidden-tag HMAC key (`tag_hmac.dart`).
- Zip-slip guard on backup restore (`backup_service.dart:125-130`); restore only when uninitialised.
- FTS query terms are quote-escaped (`document_repository.dart:253-259`); all dynamic SQL uses bind parameters.
- `FLAG_SECURE` set (`MainActivity.kt`), `allowBackup="false"`, redundant media permissions stripped.
- Orphan secure-storage cleanup after uninstall (`main.dart:23-26`).
- Logger defaults to suppressing output in release and the header explicitly forbids logging secrets.
