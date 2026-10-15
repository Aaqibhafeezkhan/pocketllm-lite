# Release signing, key hygiene and the upgrade transition

Status as of 2026-10-15 (pass 2). **No production signing key exists in this
repository or was created in this pass.** Everything below is preparation; the
maintainer must supply credentials and decisions.

## 1. What is wrong today

| # | Finding | Evidence | Severity |
| --- | --- | --- | --- |
| S1 | Published APKs are signed with an Android **debug** certificate (`CN=Android Debug`, SHA-256 `f11e976967911c8e585dd88817d6587076a802840699eebf7e3c8304bedbe3b5`), the one generated on the build machine | `docs/V1_0_38_VERIFICATION.md`; `scripts/release/verify-apk-signature.mjs` reports the same fingerprint for a local debug build | P1 |
| S2 | A file named `upload-keystore.jks` was committed on 2025-12-29 (commit `c82e363`) and removed from the tree on 2026-01-18. It is still in the **public** history of `origin/main` | `git log --all -- upload-keystore.jks` (metadata only; the file contents were not read) | **P0 if it was ever used for releases** |
| S3 | `android/key.properties.bak` was tracked since commit `816e3f8`. Its contents were deliberately **not read** in this pass, so whether it held real passwords is unknown | `git ls-files` | P0 until checked |
| S4 | The Gradle build silently fell back to the debug key when `key.properties` was absent, so an "official" build could be debug-signed without any signal | `android/app/build.gradle.kts` before this pass | P1 |

## 2. Fixed in this pass

- `android/key.properties.bak` is untracked; `key.properties*`, `*.jks`,
  `*.keystore`, `*.p12`, `*.pfx` and `*.bak` are ignored.
- `test/regressions/no_committed_secrets_test.dart` fails if any signing
  material becomes tracked again.
- `android/app/build.gradle.kts` accepts `ANDROID_KEYSTORE_PATH`,
  `ANDROID_KEYSTORE_PASSWORD`, `ANDROID_KEY_ALIAS`, `ANDROID_KEY_PASSWORD` (CI)
  or `android/key.properties` (local), and with `-Prelease.requireSigning=true`
  **fails the build** instead of using the debug key. Verified: the Gradle
  configuration step aborts with "Refusing to fall back to the debug key."
- `.github/workflows/release.yml` (manual, environment-protected) builds split
  APKs only when all four secrets exist, runs analyze and tests, verifies the
  APK signer is not a debug certificate, writes `SHA256SUMS.txt`, and uploads
  artifacts. It does not publish a GitHub release.
- `scripts/release/verify-apk-signature.mjs` and `scripts/release/checksums.mjs`.

## 3. Maintainer actions (required, cannot be done by an assistant)

1. **Decide whether `upload-keystore.jks` was ever used to sign a release.**
   Compare its certificate fingerprint with the one in section 1 using your own
   copy. If it signed anything public, or if `key.properties.bak` held its real
   passwords, treat that key as compromised: never use it again.
2. **Create a new production keystore** on a trusted machine, with strong
   unique passwords, and back it up offline in two places. Losing it means
   users can never upgrade again.
3. Store it as the protected secrets listed in `release.yml` under a GitHub
   *environment* named `release` with required reviewers.
4. Optionally purge the old files from history. This rewrites public commits,
   breaks forks and open PRs, and does **not** un-leak anything already cloned,
   so it is a cosmetic measure after step 1. It was not attempted here.
5. Update `SECURITY.md` and release notes with the production certificate
   SHA-256 so users can verify downloads.

## 4. The upgrade constraint

Android refuses to install an update whose signing certificate differs from the
installed app's. Existing users have an APK signed with the debug certificate
in section 1. A production-signed APK **cannot** be installed over it. Nothing
in the app can change that, and user data does **not** survive a forced
reinstall automatically.

### Option A: reinstall with backup and restore (always works)

1. In the old app: **Settings > Chats & Local Data**, create an encrypted
   `.pllm` backup with a password you will remember, and copy the file off the
   app's private storage (share it to Files/Drive/another device).
2. Uninstall the old app. Installed models and caches are deleted with it.
3. Install the production-signed APK and verify its SHA-256 against
   `SHA256SUMS.txt` and the certificate fingerprint published in `SECURITY.md`.
4. Restore the backup in the new app. Re-download models; they are not part
   of the backup.
5. Confirm chats, notes, memories and documents are present.

State this plainly in the release notes. The restore path is covered by
`test/services/backup_*` and the on-device integration test; a full
uninstall/reinstall/restore on hardware was **not** executed in this pass.

### Option B: signing-key rotation (only if the old key still exists)

Android 9 (API 28) and newer honour an APK Signature Scheme v3 *rotation
lineage*: the old key signs a statement that the new key is its successor, and
the OS then accepts the new key for upgrades. This needs the **original** debug
keystore that produced the published APKs. A debug keystore exists on the build
machine used in this pass (`~/.android/debug.keystore`, file presence only; not
inspected), and its certificate matches the published fingerprint.

Sketch (maintainer to run; not executed here):

```bash
apksigner rotate --out lineage --old-signer --ks ~/.android/debug.keystore \
  --new-signer --ks production.jks
apksigner sign --ks production.jks --lineage lineage --out app.apk app-unsigned.apk
```

Limits: devices on Android 7-8 (this app's minSdk is 24) ignore lineage and must
use Option A. Lineage permanently ties the new key to a debug key whose
password is the well-known default, so the new key's trust relies on keeping
the old key private. Verify on a real device with a real upgrade before
announcing.

## 5. Verification commands

```bash
# Build (CI does this; locally you need the four ANDROID_* variables)
flutter build apk --split-per-abi --release -Prelease.requireSigning=true

# Confirm the signer is not the debug certificate (needs ANDROID_HOME)
node scripts/release/verify-apk-signature.mjs build/app/outputs/flutter-apk/*-release.apk

# Checksums to publish
node scripts/release/checksums.mjs build/app/outputs/flutter-apk/SHA256SUMS.txt \
  build/app/outputs/flutter-apk/*-release.apk
```
