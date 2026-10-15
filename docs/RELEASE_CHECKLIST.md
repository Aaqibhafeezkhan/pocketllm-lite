# Release readiness checklist

Use this before tagging any release. Items marked **Blocked** need something an
assistant cannot supply. Status reflects 2026-10-15 (pass 2).

## A. Code and tests (automatable)

- [x] `dart format --output=none --set-exit-if-changed .`
- [x] `flutter analyze` has no issues
- [x] `flutter test` is green (see `PHASE_2_EXECUTION_REPORT.md` for counts)
- [x] `cd webapp && npx tsc --noEmit && npx eslint src && npm test && npx next build`
- [x] `npx playwright test` (desktop + mobile projects)
- [x] `npm audit --omit=dev` reports no high or critical issues
- [x] On-device integration tests pass on an emulator:
      `flutter test integration_test -d <android-device>`
- [ ] Integration tests pass on at least one **physical arm64** phone (Blocked: no device)

## B. Version and documents

- [ ] `pubspec.yaml` version bumped per `Agents.MD` (patch to 100, then minor)
- [ ] `CHANGELOG.md`, `RELEASE_NOTES.md`, README badge agree
      (`test/regressions/release_truth_test.dart` enforces this)
- [ ] `docs/KNOWN_LIMITATIONS.md` updated for anything new or removed
- [ ] Release notes state signing status, ABI coverage and "Cactus ships
      arm64-v8a only" honestly
- [ ] Screenshots in README and release match the shipped UI

## C. Signing and artifacts (Blocked on maintainer)

- [ ] New production keystore created, backed up, **not** `upload-keystore.jks`
- [ ] Old `upload-keystore.jks` assessed and, if it signed releases, retired
      (`docs/RELEASE_SIGNING.md` section 3)
- [ ] Protected secrets and `release` environment configured
- [ ] Release workflow run; `verify-apk-signature.mjs` passes
- [ ] `SHA256SUMS.txt` generated from the exact uploaded files
- [ ] Certificate SHA-256 published in `SECURITY.md`
- [ ] Upgrade path chosen and written in release notes (backup/restore or
      rotation lineage), tested on a real device

## D. Privacy and policy

- [ ] `assets/network_policy.json` still lists every outbound destination
- [ ] No new `http.Client`, `Dio` or `launchUrl` outside the gateway
      (regression tests enforce this)
- [ ] Strict Offline smoke test: model search, download, update check and web
      search are all blocked with a reason
- [ ] Web edition: Playwright "no third-party requests" test is green

## E. Publication (maintainer only)

- [ ] GitHub release created from a signed build, marked **latest** when it is
      the recommended download (it currently is not; see audit O1)
- [ ] Repository description, topics and social preview updated
- [ ] Announcement copy reviewed against `GROWTH_STRATEGY.md` rules (no
      absolute offline claims, no unmeasured performance claims)
