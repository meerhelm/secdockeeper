# Roadmap — functional suggestions

A categorized list of features that could be added to SecDockKeeper. Items
already on the root [`README.md`](../README.md#roadmap) roadmap are marked
*(roadmap)*; the rest are net-new suggestions.

This page is intentionally just a list of ideas — not commitments. Before
building any of them, write a short design note and update the relevant
architecture / security docs.

## Vault security & key management

1. **Master password change** — re-wrap every DEK + re-key SQLCipher
   (`PRAGMA rekey`) atomically, with checkpointed progress so a kill
   mid-rotation is recoverable. *(roadmap)*
2. **Stealth / duress vault** — second password unlocks an alternate
   document set; UI must look identical when the wrong one is given. Shape
   the schema so two KEKs can coexist (e.g. two descriptors). *(roadmap)*
3. **Argon2id parameter upgrade** — when defaults bump, offer a one-tap
   "harden vault" that re-derives the KEK with new params and re-keys
   SQLCipher.
4. **App PIN as second factor** — short PIN gate *before* biometric prompt,
   separate from the master password (PIN unwraps a sealed master).
5. **Panic wipe** — N failed unlocks (configurable) deletes `vault.json` +
   `vault.db` + `blobs/`. Off by default; opt-in from settings.
6. **iOS background blur overlay** — [`security.md`](security.md#anti-snoop--lifecycle-defaults)
   already flags this as a gap on iOS; trivial to add via lifecycle observer.
7. **Memory hygiene pass** — best-effort zeroization on `vault.lock()`
   (overwrite `Uint8List`s for KEK / tag-HMAC / DEK before drop).
48. **Multi-vault profiles** — multiple named vaults on the same device
    (e.g. "Personal", "Work"), each with its own KEK, SQLCipher DB, blob
    store, and `LockSettings`. Vault picker shown ahead of the lock screen
    when more than one exists. `VaultPaths` parameterized by vault id;
    biometric keystore slots namespaced per vault.
    **Tradeoff with #2 (stealth vault):** stealth requires the second vault
    to be *indistinguishable* from "no second vault" — so a multi-vault
    picker that lists them would defeat it. If both ship, the stealth vault
    must be excluded from the picker and only reachable by typing its
    password on a single-vault-style lock screen. Pick the design intent
    before building either.

## Document acquisition

8. **In-app document scanner** — camera + edge detection + perspective
   correction + multi-page PDF assembly. *(roadmap)*
9. **OS share-target intent** — register the app as a share target so
   users can send a file from any other app straight into the vault.
10. **Clipboard image import** — paste-from-clipboard on the FAB long-press.
11. **Bulk import progress UI** — per-file status (pending / OCR /
    encrypting / done / error) with retry-failed.
12. **Re-import shared package without duplicating** — detect that the
    incoming `.sdkblob` is one we already have (by content hash post-decrypt)
    and offer "skip / replace / keep both".

## List & organization

13. **Multi-select mode** — long-press to enter; bulk delete / move-to-folder
    / tag / share / export. *(roadmap)*
14. **Sort options** — by name / created / updated / size / classification
    (currently fixed).
15. **Filters beyond tags** — by MIME, by classification (the auto-classifier
    output is unused as a filter today), by date range.
16. **Folder & tag colors** — schema already has `color` columns on both;
    UI never sets or shows them.
17. **Saved searches** — persist query + filters (folder scope, tag set,
    MIME) as a named entry.
18. **Auto-tag rules** — "if classification == invoice → assign #finance";
    deterministic post-import hook.
19. **Favorites / pinned** — boolean column, sticky at the top of the list.
20. **Soft delete with 30-day trash** — currently delete is irreversible; a
    recoverable bin (still encrypted, just flagged) reduces foot-gun risk.

## Viewing

21. **Built-in PDF viewer** — avoid the temp-file dance and the system
    viewer's caches. *(roadmap)*
22. **Built-in image viewer** — pinch-zoom, swipe between images in same
    folder.
23. **In-memory thumbnails for cards** — decrypt-on-demand, hold only in
    RAM, drop on lock. The redesign brief calls this out specifically.
24. **OCR text: copy + in-text search + highlight matches** — today it's a
    static `bodyMedium` block on the detail screen.
25. **Re-run OCR** — for documents imported before OCR was run, or if the
    user wants a higher-fidelity pass.
26. **OCR for PDF pages** — currently OCR only fires for image MIMEs.

## Reminders & lifecycle

27. **Expiry reminders** — passport / license / contract expiry date stored
    encrypted; local notification N days before. Notification body must be
    generic ("A document needs your attention") to not leak content.
    *(roadmap)*
28. **Document notes field** — small encrypted free-text column per
    document.

## Sharing

29. **Share key TTL / revocation log** — the format already supports
    re-encryption per share; track issued keys per document so the user can
    see "you shared this 3 times".
30. **QR transfer for `.sdkkey.json`** — small enough to fit; lets users
    hand-deliver the key out-of-band.
31. **Multi-document share bundle** — single `.sdkblob` archive + manifest,
    one `.sdkkey.json` covering the bundle (still re-encrypted on import per
    current contract).

## Backup

32. **Encrypted cloud backup** — push the existing ZIP to user-chosen Drive
    / iCloud / WebDAV. Server stores ciphertext only; passphrase never leaves
    device.
33. **Backup verification** — open the archive, validate manifest + each
    blob's MAC, before reporting success. Currently the export is
    fire-and-forget.
34. **Backup reminders** — local notification when last backup is older
    than X days. Generic body.
35. **Incremental backup** — only changed blobs since last manifest;
    smaller archives for large vaults.

## Search

36. **Search history (session-scoped)** — recent queries dropdown, cleared
    on `vault.lock()` along with the temp dir.
37. **Snippet highlighting** — FTS5 supports `snippet()` / `highlight()`
    — surface a 2-line match excerpt under each result.
38. **Tag autocomplete on visible tags only** — speeds up typing without
    violating the hidden-tag constraint.

## Settings (currently no settings UI exists)

39. **Settings screen** — auto-lock seconds, biometric on/off, panic-wipe,
    Argon2id profile, theme. Today these are stored but only `LockSettings`
    keys are user-tunable, and there's no UI surface. *(The redesign brief
    says no settings page; worth pushing back — at minimum an auto-lock
    control is needed.)*
40. **Per-vault "high-paranoia" preset** — bumps Argon2id, sets auto-lock
    to 0, enables panic-wipe, disables biometric, in one toggle.

## Diagnostics & integrity

41. **Vault health check** — find orphan blobs (no DB row), missing blobs
    (row points at gone file), MAC failures across all blobs. Report-only
    first; offer cleanup as a second step.
42. **Storage breakdown** — per-folder, per-MIME, per-classification size
    totals.
43. **Local access log** — encrypted, in-app, append-only: opened doc X at
    time T, exported doc Y, restored backup Z. No analytics, no network.

## Cross-platform

44. **Web build via drift + sqlite3 wasm** — *(roadmap)*; would need a
    separate blob store abstraction (OPFS).
45. **Desktop polish** — proper file picker, drag-drop, window-level
    lock-on-blur on macOS.

## Accessibility & i18n

46. **Localization** — currently English-only; security copy especially
    benefits from native-language clarity.
47. **Screen reader labels** for sensitive surfaces (lock state, hidden-tag
    sheet) without leaking hidden-tag content to TalkBack / VoiceOver.

## Suggested first cuts

If prioritized for impact vs. effort, an opinionated first slice:

1. Multi-select bulk ops (#13)
2. Master password change (#1)
3. OS share-target intent (#9)
4. Settings screen + auto-lock UI (#39)
5. Document scanner (#8)
6. Built-in PDF / image viewer (#21–22) — closes the temp-file plaintext
   window
7. Expiry reminders (#27)
8. Soft-delete trash (#20)
