# Release prep checklist

Manual steps that have to happen on a developer machine — automated tooling
can't do these for you. This list is meant to be worked through once before
the first public push and reviewed on every subsequent major release.

## Done automatically

- `LICENSE` — Apache-2.0, copyright Valentin Sobolev 2026.
- `pubspec.yaml` description — replaced the Flutter scaffold default with a
  real one-liner.
- `.gitignore` — `.claude/`, `compliance/`, vault test data, signing
  artefacts, `.env*` files added.
- `compliance/` folder relocated to `~/Documents/secdockeeper-compliance/`
  so the export-control PII never lives inside the repo.
- iOS export-compliance keys (`ITSAppUsesNonExemptEncryption`,
  `NSPhotoLibraryUsageDescription`) added to `ios/Runner/Info.plist`.
- iOS Podfile post-install hook configured to preserve dSYMs.

## To do before pushing the repo public

### 1. Decide on git history

Existing commits include identifying information that public history would
expose:

- `valentinsobolev@gmail.com` (personal Gmail)
- `valentinsobolev@Valentins-MacBook-Pro.local` (personal hostname)

Pick **one** option:

**Option A — squash to a fresh initial commit (simple, loses history):**

```bash
# from a clean working tree, on a branch you don't mind discarding
git checkout --orphan public-main
git add .
git -c user.email="<id>+valentinsobolev@users.noreply.github.com" \
    -c user.name="Valentin Sobolev" \
    commit -m "feat: initial public release"
# review, then replace main when ready:
# git branch -M public-main main
# git push -u origin main --force-with-lease   # only if remote is yours
```

**Option B — rewrite all author/committer emails (keeps history):**

```bash
pip install git-filter-repo   # one-time
git filter-repo \
  --email-callback '
    return b"<id>+valentinsobolev@users.noreply.github.com"
      if email in (
        b"valentinsobolev@gmail.com",
        b"valentinsobolev@Valentins-MacBook-Pro.local",
      )
      else email
  ' \
  --name-callback 'return b"Valentin Sobolev"'
```

Replace `<id>` with your numeric GitHub user id (look it up at
`https://api.github.com/users/<your-username>`).

### 2. Lock future commits to the no-reply email

```bash
cd /Users/valentinsobolev/Development/meerhelm/secdockeeper
git config --local user.email "<id>+valentinsobolev@users.noreply.github.com"
git config --local user.name  "Valentin Sobolev"
```

`--local` keeps this scoped to this repo only.

### 3. Replace the placeholder LICENSE copyright if needed

`LICENSE` currently reads `Copyright 2026 Valentin Sobolev`. Update if you
prefer a trade name (`Valentin Sobolev — StellarLab`) or a different year
range later (`2026–2027`).

### 4. Optional: scrub iOS Apple Developer Team ID

`ios/Runner.xcodeproj/project.pbxproj` contains
`DEVELOPMENT_TEAM = SS9RT9SXWX`. This identifies your Apple Developer
account. Many open-source iOS apps publish theirs; if you'd rather not,
move it to a per-machine xcconfig override:

1. Create `ios/Flutter/DevelopmentTeam.xcconfig` (gitignored).
2. Set `DEVELOPMENT_TEAM = SS9RT9SXWX` in that file.
3. Reference it from `Debug.xcconfig` and `Release.xcconfig` with
   `#include? "DevelopmentTeam.xcconfig"`.
4. Replace the inline value in `project.pbxproj` with empty string.

Add to `.gitignore`:

```gitignore
ios/Flutter/DevelopmentTeam.xcconfig
```

### 5. Set up Android release signing

`android/app/build.gradle.kts` currently signs releases with the debug key
(there's a `TODO` comment). Before any Play Store submission:

1. Generate a release keystore (kept outside the repo).
2. Create `android/key.properties` (gitignored — already covered).
3. Update the gradle file's `signingConfigs` and `buildTypes.release.signingConfig`.

### 6. Pre-flight: verify nothing sensitive is staged

```bash
git status
git diff --cached
```

If anything from `compliance/`, `.claude/`, a keystore, or `.env*` shows up,
stop and fix the `.gitignore`.

## Compliance maintenance (lives outside the repo)

Documents in `~/Documents/secdockeeper-compliance/`:

- Fill in `[00-XXX]` postal code and `[+48 phone]` placeholders.
- Sign and date `us-export-classification.md` and
  `france-general-use-attestation.md`, export to PDF, combine into the
  Apple upload bundle.
- File the BIS/NIST annual self-classification report by **2027-02-01**
  for calendar year 2026 (and every February thereafter).
