# Security model

This page is about cryptography, key management, and the lifecycle of secret
material. If you're touching anything in [`lib/core/crypto/`](../lib/core/crypto/)
or [`lib/features/vault/`](../lib/features/vault/), read this first.

The high-level pitch is in the root [`README.md`](../README.md#how-encryption-works);
this page is the operational detail.

## Threat model

We protect against:

- **Device theft / cold attack**: an adversary with the powered-off or locked
  device cannot decrypt anything without the master password.
- **Casual snooping**: foreground previews and screenshots of the unlocked app
  are blocked (`FLAG_SECURE` on Android), and the app auto-locks when
  backgrounded.
- **App-data filesystem inspection**: the SQLCipher database is encrypted;
  individual blob files are AEAD-sealed. Filenames are random UUIDs.
- **Compromised file shares**: the document sharing format separates the
  ciphertext (`.sdkblob`) from the wrapping key (`.sdkkey.json`) so they can be
  delivered over different channels. Capturing only one is useless.
- **Online password guessing on a recovered device**: panic mode (see
  [`features.md#panic-mode`](features.md#panic-mode)) imposes an escalating
  lockout (10m → 30m → 1h → 1d, every 3 fails, no reset except on success)
  or — at the user's choice — silently wipes the vault on the 3rd wrong
  attempt. Biometric is suppressed after any wrong password to prevent
  attacker pivoting between unlock surfaces.

We do **not** protect against:

- A compromised device with an active session (rooted, with shell, while
  unlocked). The KEK is in process memory while unlocked.
- A keylogger or screen recorder that captures the password as it is typed.
- A coerced-disclosure scenario for hidden tags. Hidden tags give *deniability*
  (you can claim there are none and the UI agrees) but a forensic dump of the
  DB will show that hashes exist.

## Key hierarchy

```
master password
    │
    ▼ Argon2id (salt, m, t, p)
KEK ─ AES-256 key, lives in memory only while unlocked
    │
    ├─▶ base64(KEK bytes)  ─▶ SQLCipher passphrase for vault.db
    │
    ├─▶ AES-GCM wrap        ─▶ wrapped DEK stored next to each document
    │           │
    │           └─▶ DEK     ─▶ AES-GCM encrypts the document blob
    │
    └─▶ HKDF(info="sdk-tag-hmac")
                 │
                 └─▶ HMAC key  ─▶ HMAC(name) for hidden tag indexing
```

### Argon2id KDF

Implemented by [`Kdf`](../lib/core/crypto/kdf.dart) using
`package:cryptography`'s `Argon2id`. Parameters:

```dart
static const defaultParams = KdfParams(
  memory: 19 * 1024,    // 19 MiB — OWASP minimum
  iterations: 2,
  parallelism: 1,
  hashLength: 32,
);
```

If you raise these, unlock gets slower in proportion. The `vault.json`
descriptor stores the chosen parameters, so old vaults keep using the
parameters they were created with — only new vaults pick up the new defaults.

### KEK as SQLCipher key

`VaultService._kekToDbPassword` base64-encodes the KEK bytes and uses the
result as the SQLCipher passphrase. This is the simplest way to get a single
master credential to gate both file blobs and metadata. **There is no second
password and no second key derivation step** — keep it that way.

### DEKs

Per-document data encryption keys. Generated at import time as 32 random
bytes from a CSPRNG, wrapped under the KEK with AES-GCM, and stored as three
columns on the `documents` row: `dek_wrapped`, `dek_nonce`, `dek_mac`.

DEKs are unwrapped on read (`DocumentOpenService.decryptBytes`) and discarded
immediately after the file is decrypted. They are never persisted in the
clear and never live longer than a single open operation.

### Tag HMAC key

[`tag_hmac.dart`](../lib/core/crypto/tag_hmac.dart) derives an HMAC key from
the KEK using HKDF with `info: "sdk-tag-hmac"`. This key is used for hidden
tag hashing only. Keeping it derived (not stored) means it inherits the KEK's
lifecycle: alive when unlocked, gone when locked.

## Vault lifecycle

[`VaultService`](../lib/features/vault/vault_service.dart) is a `ChangeNotifier`
that owns the full set of in-memory secrets:

```dart
VaultDatabase? _vaultDb;
SecretKey? _kek;
SecretKey? _tagHmacKey;
```

State transitions:

```
                  initialize(password)
                  ┌─────────────────────┐
                  ▼                     │
uninitialized ────┘                     │
                                        │
                            unlock(password)
locked ◄────── lock() ──── unlocked ◄───┘
```

- **`initialize(password)`** runs once, in `OnboardingCubit`. Generates a
  fresh salt, derives the KEK, opens (and creates) the SQLCipher DB, writes
  `vault.json`, and notifies. After this, the vault is `unlocked`.
- **`unlock(password)`** opens an existing DB. Returns `false` if the
  password is wrong (caught from a SQLCipher exception inside `try`). On
  success, derives the KEK + tag HMAC key and notifies.
- **`lock()`** is invoked from three places:
  1. `LockVaultUseCase` (the explicit lock button)
  2. `AutoLockController` on `paused`/`hidden`/`inactive` lifecycle events
  3. `BackupService.exportVault()` before zipping
  It clears `_kek`, `_tagHmacKey`, closes `_vaultDb`, and notifies.

`notifyExternalChange()` is used by `BackupService.restoreFromArchive` so the
router redirect kicks in after a restore (the descriptor file appeared, but
the cached state needs a refresh).

### Panic mode and `destroy()`

`VaultService.destroy()` is the one path that nukes the entire vault root
(`vault.json` + `vault.db` + `blobs/`) and recreates an empty shell. It is
called from two places:

1. The "Destroy vault" menu in the documents list (with a `DESTROY`-typed
   confirmation).
2. `RegisterFailedUnlockUseCase` when the user's panic policy is
   `PanicAction.wipe` and the wrong-attempt counter hits the threshold —
   *no warning, no confirmation*. The user opted in at onboarding /
   settings; trigger time is silent on purpose.

Both paths funnel through `DestroyVaultUseCase`, which also calls
`DocumentOpenService.deleteAllTemp()` and `LockSettings.clearAll()` so no
plaintext temp files or Keychain leftovers survive the destroy.

**Counter persistence — known limitation.** The failed-attempt counter and
`lockedUntil` live in `flutter_secure_storage` (Keychain on iOS, EncryptedSharedPreferences on
Android). The integrity of the panic gate therefore relies on the platform's
secure storage being tamper-resistant. A rooted/jailbroken device with shell
access could roll back the counter between attempts. Don't model panic mode
as a defense against that adversary — it's a guard against an attacker who
recovers the locked device and tries to brute-force the unlock screen.

## Decrypted plaintext lifetime

Two places hold plaintext, and only briefly:

1. **Import re-encryption.** `DocumentImportService` reads the file into
   memory (`Uint8List`), encrypts it under a fresh DEK, and writes the
   ciphertext. The plaintext buffer is dropped at the end of the function.
2. **System viewer.** `DocumentOpenService.decryptToTempFile` writes the
   plaintext to `<tempDir>/sdk_view/<originalName>` so `OpenFilex` can hand
   it to the OS viewer. `LockVaultUseCase` (and `vault.lock()` indirectly,
   via the cubit's lock action) calls `DocumentOpenService.deleteAllTemp()`
   which removes the directory recursively.

Do **not** introduce a long-lived decrypted cache, an in-memory document
preview, or a thumbnail cache that holds plaintext bytes. If you need
in-app previews, decrypt-on-render and discard.

## Hidden tags

Hidden tags exist to satisfy a deniability requirement: a coerced unlock
should not reveal that there are tags called "passport" or "project-x"
attached to documents. The UI should look identical whether hidden tags
exist or not.

[`HiddenTagRepository`](../lib/features/hidden_tags/hidden_tag_repository.dart)
stores three things per assignment:

| Column | Content |
| --- | --- |
| `tag_hash` | `HMAC(tagHmacKey, name)` — used for lookups |
| `encrypted_name` + `encrypted_name_nonce` + `encrypted_name_mac` | AES-GCM-sealed plaintext name, key=KEK |

When the user types `name` into the search bar, the search code calls
`hiddenTags.findDocumentsByName(name)` which hashes the input with the same
HMAC key and looks up the hash. Match → reveal documents. Miss → silence.

The encrypted name is only used to populate the `HiddenTagsSheet` (the user
opens a known document to manage its hidden tags). It's never decrypted to
populate any kind of "all tags" list, autocomplete, or count surface.

### Invariants for hidden tags

- **No enumeration.** There is no method that lists all hidden tags across
  all documents. `namesForDocument(id)` exists, but it's scoped to a single
  document the user is already looking at.
- **No counts.** No "you have N hidden tags" indicator anywhere.
- **No autocomplete.** Search input does not suggest hidden tag names; the
  user must type the full name. Partial matches are intentionally not
  supported — they would leak prefixes.
- **HMAC, not hash.** A plain hash like SHA-256 would let an attacker who
  obtains the DB run a dictionary attack offline. The HMAC key derivation
  ties the hash to the KEK, so dictionary attacks need the password too.

If you add a feature involving hidden tags, re-read this section. The
constraints look quirky in isolation — they exist to preserve deniability
end to end.

## Sharing format

[`ShareService.exportDocument`](../lib/features/sharing/share_service.dart)
re-encrypts the document under a **fresh** DEK (not the original) and writes
two files:

- `<stem>.sdkblob` — the AES-GCM ciphertext
- `<stem>.sdkkey.json` — JSON with version, original name, MIME, plaintext
  size, base64(DEK), nonce, and MAC

The recipient's `ShareService.importPackage` decrypts using the JSON's DEK,
then re-imports through `DocumentImportService.importBytes` — which generates
yet another fresh DEK wrapped under the recipient's KEK. The shared key is
discarded.

This means a leaked `.sdkkey.json` only compromises the one document, not the
sender's vault. And revoking a shared copy means: don't reuse the same
`.sdkkey.json` again. (There is currently no expiry mechanism — see the
roadmap in the root README.)

## Anti-snoop / lifecycle defaults

[`AutoLockController`](../lib/features/security/auto_lock_controller.dart)
listens to `WidgetsBindingObserver` lifecycle events. On `paused`, `hidden`,
or `inactive`, it schedules `vault.lock()` after `LockSettings.autoLockSeconds`
(default 60s, settable to 0 = immediate).

On Android, the manifest sets `FLAG_SECURE` so screenshots and the
recent-apps preview are blacked out. iOS does not have a direct equivalent;
the app should add a manual blur overlay on `inactive` if iOS becomes a
priority target.

## Things to avoid

- **Don't pass the password around.** It enters `OnboardingCubit.create` /
  `LockCubit.submit`, gets handed to `Kdf`, and is dropped. After that, only
  the KEK exists.
- **Don't log secrets.** Use `log.x(...)` from
  [`lib/core/logging/app_logger.dart`](../lib/core/logging/app_logger.dart)
  for all logging — never `print` / `debugPrint` / `Logger()` instances of
  your own. The `DevelopmentFilter` suppresses output in release builds, but
  do not rely on that: never log the password, the KEK, a DEK, a hidden tag
  name, or decrypted document bytes. Even nonces should not be logged with
  the associated ciphertext — they're not secret in isolation, but pairing
  them in logs makes plaintext recovery a one-bug-away problem.
- **Don't catch and ignore decryption errors.** `Aead.open` throws on MAC
  failure; that's a tampered or wrong-key blob and should propagate.
- **Don't add a "remember password" feature outside of the existing
  biometric flow.** The biometric flow seals the password in the platform
  keystore via `flutter_secure_storage` — that is the only sanctioned
  place for the plaintext password to be persisted.
