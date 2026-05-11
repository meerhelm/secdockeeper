# Export Compliance — SecDockKeeper

SecDockKeeper uses non-exempt encryption (AES-256-GCM for blobs, SQLCipher AES-256
for the metadata DB, Argon2id KDF, HKDF, HMAC-SHA256). Because the source is
publicly available on GitHub, the project relies on the **publicly available
encryption source code** notification under **EAR §742.15(b)** to satisfy U.S.
export control requirements. No CCATS, ERN, or annual self-classification report
is required while the source remains public.

## Open source + paid in-app purchases

Selling a subscription or in-app purchases on top of an open-source app does
**not** break the §742.15(b) exemption. The exemption is about the *source code*
being publicly available; the *binary* on the App Store can be paid, free, or a
mix. Apps like Standard Notes and Bitwarden ship paid features on top of public
encryption source under the same regime.

SecDockKeeper's setup: **all** code — free features, paid features, and the
crypto that backs both — lives in the public `meerhelm/secdockeeper` repo.
Paid tiers are unlocked at runtime by an entitlement / receipt check (App
Store IAP, Play Billing), not by shipping different code. This is the cleanest
shape for §742.15(b): the binary corresponds 1:1 to the public source.

The one thing that *would* break the exemption is closing the source — if the
repo goes private or paid features start shipping from a closed-source branch,
§742.15(b) no longer covers the binary and the project would need to switch to
§740.17(b)(1) self-classification (see bottom of this doc).

Practical rule going forward: any new cryptographic functionality must land in
the public repo *before* it ships in a store build.

## One-time BIS / NSA notification

Send the email below from `contact@meerhelm.com` **before** the first App Store
/ Play Store release that contains the encryption code.

- **From:** `contact@meerhelm.com`
- **To:** `crypt@bis.doc.gov`
- **Cc:** `enc@nsa.gov`
- **Subject:** Notification of Publicly Available Encryption Source Code — SecDockKeeper

```
To whom it may concern,

Pursuant to 15 CFR §742.15(b), this email serves as notification that
publicly available encryption source code has been made available on the
internet at the following location:

    https://github.com/meerhelm/secdockeeper

Submitter:        Valentin Sobolev (Meerhelm)
Email:            contact@meerhelm.com
Project name:     SecDockKeeper
Description:      Local-first, end-to-end encrypted document vault for
                  Android, iOS, and macOS. Built with Flutter / Dart.
                  Distributed as open source on GitHub. The App Store and
                  Play Store binaries are built from the same public source.
                  Optional paid features (in-app purchase subscription) are
                  also open source in the same repository and are unlocked
                  at runtime by an entitlement / receipt check; no
                  closed-source code or undisclosed cryptographic
                  functionality is shipped.

Cryptographic functionality:
  - AES-256-GCM authenticated encryption for document blobs and wrapped
    per-document data-encryption keys (DEKs).
  - SQLCipher (AES-256) full-database encryption for metadata.
  - Argon2id password-based key derivation (OWASP minimum parameters)
    producing the Key-Encryption-Key (KEK).
  - HKDF-SHA256 sub-key derivation; HMAC-SHA256 for hidden-tag indexing.
  - Random per-document DEKs wrapped under the user's KEK with AES-GCM.
  - All cryptographic primitives are provided by widely available open
    source libraries: `cryptography` and `cryptography_flutter` (Dart,
    by Gohilla), `sqflite_sqlcipher` (SQLCipher binding), and
    `flutter_secure_storage` (platform Keychain / Android Keystore for
    biometric-sealed master password storage).

The repository is public, unrestricted, and free of charge; no controls
on access (no registration, login, or fee) are imposed on the source code.

This notification is being sent simultaneously to crypt@bis.doc.gov and
enc@nsa.gov as required.

Regards,
Valentin Sobolev
Meerhelm
contact@meerhelm.com
```

## After sending

1. Save the sent email (and any acknowledgement) as PDF — App Store Connect's
   export-compliance review may ask you to upload proof.
2. Once Apple issues an `ITSEncryptionExportComplianceCode` for an approved
   build, add it to both `Info.plist` files (iOS + macOS) right below
   `ITSAppUsesNonExemptEncryption`:

   ```xml
   <key>ITSEncryptionExportComplianceCode</key>
   <string>PASTE_CODE_HERE</string>
   ```

   Until the code is added, App Store Connect will show "Missing Compliance"
   on each build and route you through the export-compliance questionnaire —
   that is the intended state for the first submission.
3. Re-send the notification email **only if the public URL changes**
   (e.g. the repo moves to a different org). Code updates do not require
   re-notification.

## If the project ever goes closed-source

The §742.15(b) exemption no longer applies. Switch to **EAR §740.17(b)(1)**:
self-classify under ECCN 5D992.c and file an annual self-classification
report to BIS and the U.S. Census Bureau by **February 1** of each year.
