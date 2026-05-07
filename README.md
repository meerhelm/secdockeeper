# SecDockKeeper

A local-first, end-to-end encrypted document vault. Store passports, contracts,
scans, and any other sensitive files on your device — encrypted with a master
password that never leaves the phone. Cross-platform Flutter app, optimised for
Android.

## Highlights

- **Envelope encryption.** Every document gets its own AES-256-GCM data key
  (DEK), wrapped by a master key (KEK) derived from your password via
  Argon2id. The plaintext is never stored anywhere.
- **Encrypted metadata.** Names, tags, OCR text, and FTS index all live inside
  a SQLCipher database keyed off the same master.
- **Deniable hidden tags.** Tags can be stored as HMAC hashes only — they
  never appear in any list, autocomplete, or count. They reveal documents only
  when their exact name is typed into the search bar.
- **OCR + auto-classification.** Imported images are scanned with Google ML
  Kit on-device and tagged automatically (passport, invoice, contract, etc.).
- **Folders.** Flat folder grouping with a quick-filter chip row.
- **Sharing.** Export a document as `.sdkblob` + a separate `.sdkkey.json`.
  Send the blob through any channel; deliver the key over a second channel.
  The recipient's app re-wraps the DEK under their own KEK.
- **Full backup.** One-click export of the entire vault as a portable ZIP for
  device migration. Restore on the new device with the same master password.
- **Biometric unlock.** Optional fingerprint / Face ID. The master password is
  sealed in the platform keystore.
- **Anti-snoop defaults.** Auto-lock when the app is backgrounded.
  `FLAG_SECURE` blocks screenshots and obscures the task-switcher preview on
  Android.
- **Material 3 UI.** Inter typography, light and dark theme, semantic
  surfaces, mime-aware icon accents.

## How encryption works

```
master password ──Argon2id(salt, m=19MiB, t=2)──▶ KEK (256-bit)
                                                    │
                                                    ├──▶ unwraps each DEK
                                                    │      └──▶ decrypts blob (AES-GCM)
                                                    │
                                                    ├──▶ unlocks SQLCipher metadata DB
                                                    │
                                                    └──▶ HKDF ▶ HMAC key for hidden-tag hashing

per-document file ──AES-256-GCM(DEK, nonce)──▶ blobs/<uuid>.enc
DEK ──AES-256-GCM(KEK, nonce)──▶ wrapped DEK stored in metadata DB
```

The vault descriptor (`vault.json`) stores only the Argon2 salt and KDF
parameters in plaintext — they are useless without the password.

For sharing, the document is re-encrypted with a fresh DEK so each shared
instance has a unique key that can be revoked independently.

## Requirements

- Flutter 3.38 or newer
- Android 7.0+ (API 24+) — primary target, includes SQLCipher and Google ML Kit
- iOS 12+ — should build, requires Xcode and a recent CocoaPods setup
- macOS — builds for personal use
- Web / Linux / Windows are not supported in the current storage layer

## Build and run

```bash
# Install Dart packages and platform pods
flutter pub get

# Run on a connected Android device or emulator
flutter run -d <device-id>

# Or produce an installable APK
flutter build apk --debug --target-platform android-arm64 --split-per-abi
```

The Android APK is written to
`build/app/outputs/flutter-apk/app-arm64-v8a-debug.apk`.

## Project layout

```
lib/
  app/                 — theme, app shell, dependency container (AppScope)
  core/
    crypto/            — Argon2id KDF, AES-GCM AEAD, envelope helpers, HMAC
    storage/           — SQLCipher database, blob filesystem store, paths
  features/
    onboarding/        — first-run vault creation
    vault/             — VaultService, lock screen, vault descriptor
    documents/         — Document model, repository, import, list, detail, viewer
    folders/           — flat folder hierarchy and picker sheet
    tags/              — regular tags and tag picker sheet
    hidden_tags/       — deniable HMAC-indexed tags
    ocr/               — ML Kit text recognition + keyword classifier
    sharing/           — per-document export with separate DEK key file
    backup/            — full vault ZIP export and restore
    security/          — biometrics, auto-lock controller, lock settings
```

## Security notes

- The Argon2id parameters default to `m=19 MiB`, `t=2`, `p=1` — the OWASP
  minimum. Bump `KdfParams.defaultParams` if you want a stronger profile and
  can afford slower unlock on older hardware.
- Decrypted plaintext exists only briefly: in memory while the file is being
  re-encrypted on import, and in a per-session temporary file while the system
  viewer reads it. The temp directory is wiped on lock.
- Hidden tags are stored only as HMAC hashes plus an AES-GCM-encrypted name
  blob keyed by the KEK. The hash domain key is derived from the KEK via HKDF.

## Roadmap

Planned features that are not yet implemented:

- Built-in PDF and image viewer to avoid temporary files
- Multi-select for bulk move / tag / delete
- Document scanner (camera capture + edge detection + multi-page PDF)
- Master password change with re-wrap of all DEKs
- Expiry reminders for time-sensitive documents (passport, license)
- Stealth vault — second password reveals an alternate document set
- Web build with an alternative storage layer (drift + sqlite3 wasm)

See the full [ROADMAP.md](ROADMAP.md) for detailed functional suggestions and cryptographic security plans.

## License

Licensed under the [Apache License, Version 2.0](LICENSE). See the
[`LICENSE`](LICENSE) file for the full text.

## Reporting security issues

Please do not file public issues for security vulnerabilities. See
[`SECURITY.md`](SECURITY.md) for the responsible-disclosure policy.
