# Security policy

SecDockKeeper is an end-to-end encrypted document vault. Bugs in cryptography,
key management, or session lifecycle can directly compromise user data, so we
treat security reports as a first-class priority.

## Reporting a vulnerability

**Please do not open a public GitHub issue for security problems.** A public
report gives attackers a head start and may expose users before a fix ships.

Instead, use one of the following private channels:

- **GitHub private vulnerability reporting** (preferred): open the
  [Security advisories](../../security/advisories/new) tab on this repository
  and submit a draft advisory. This is end-to-end private between you and the
  maintainer.
- **Email**: <!-- TODO: replace with a monitored address before pushing public -->
  `security@<your-domain>` — please use the PGP key linked in the maintainer's
  GitHub profile if you can.

Include in your report:

1. A clear description of the issue and its impact.
2. Steps to reproduce, or a proof-of-concept. A minimal failing test against
   `lib/core/crypto/` is ideal.
3. The commit hash you observed it on.
4. Your name or handle for the credit line, or a request to stay anonymous.

We will acknowledge receipt within **5 business days**, agree on a disclosure
timeline with you, and aim to ship a fix within **90 days** of confirmation.
Critical issues affecting at-rest data confidentiality are prioritised over
that window.

## Scope

In scope:

- Code under [`lib/`](lib/) — especially [`lib/core/crypto/`](lib/core/crypto/),
  [`lib/core/storage/`](lib/core/storage/), and
  [`lib/features/vault/`](lib/features/vault/).
- The on-disk format: `vault.json`, the SQLCipher `vault.db`, the
  `blobs/<uuid>.enc` files, the `.sdkblob` / `.sdkkey.json` sharing format,
  and the full-vault backup ZIP.
- Auto-lock and biometric unlock flows.
- Build configuration that affects shipped binaries (Android signing,
  ProGuard/R8 rules, iOS entitlements).

Out of scope:

- Findings against third-party dependencies — please report those upstream
  (e.g. SQLCipher, `package:cryptography`, Google ML Kit). We will of course
  fix our own usage if it is the cause.
- Threats explicitly excluded by the [threat model](docs/security.md):
  active malware on a rooted device with an unlocked session, screen
  recorders, keyloggers capturing the master password as it is typed, and
  forensic detection that hidden-tag hashes exist (hidden tags provide
  deniability *to the UI*, not against a forensic DB dump).
- Issues that require physical access to an unlocked device while the user is
  signed in.
- Self-XSS or social-engineering scenarios that do not involve a code defect.

## Supported versions

The project is pre-1.0. Only the `main` branch receives security fixes.
Releases will be tagged once the project reaches a stable version; until
then, please report against the latest commit on `main`.

## Disclosure

Once a fix is available we will:

1. Publish a security advisory on GitHub describing the issue, the affected
   versions, and the fix.
2. Credit the reporter unless they have asked to remain anonymous.
3. Bump the relevant `KdfParams` or storage schema version if the fix changes
   the on-disk format, and document the migration in the release notes.

Thank you for helping keep SecDockKeeper users safe.
