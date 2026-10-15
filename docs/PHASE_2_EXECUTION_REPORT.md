# Phase 2 execution report

Date: 2026-10-15. Branch `claude/quality-growth-pass-2` (23 commits, 127 files).
Not pushed, not merged, no release created, no public setting changed.

## 1. Initial state

- Pass 1 was already merged on the remote as PR #360 (merge commit `2fd1587`),
  while local `main` was at `6504cdd`. Local `main` was fast-forwarded (no
  rewrite) and the branch cut from `2fd1587`.
- Baseline: 151 Flutter tests, analyze clean, 7 ESLint errors, 9 npm advisories.

## 2. Preserved

All pass-1 fixes, tests and documents are intact. Docs were extended with
dated "pass 2" sections instead of replaced; `EXECUTION_REPORT.md` has an
addendum correcting the "not pushed" wording.

## 3. Issues fixed (original IDs)

O3 web_search, O4 site GitHub call, O5 npm advisories (9 to 0), O6 redirects,
O7 loopback, O8 IPv6, O10 ESLint (7 to 0, blocking in CI), O14 canned replies,
O19 localhost probe, O20 sandbox defaults. Partly: O9 `finish_reason`, O16
localization, U4, U6. Assessed with no code change possible: O13 backend, O15
PDF licence. Open for the maintainer: O1, O2, O11, O12, **O17 (P0)**.
Tasks C-1 to C-6, C-9, C-11, C-12 done; C-7, C-8, C-10 partly.

## 4. Implemented

Web: sandbox policy gate, connect-model card, labelled opt-in demo, build-time
releases with an APK-aware download target, Vitest and Playwright suites in CI.
Android: first-model onboarding step, model chip and sheet, overflow menu,
notes manager, language picker and wired localization, tool confirmation
dialog, compatibility report copy, PDF backend interface. Security: per-hop
redirect policy, strict loopback, API Host/Origin/timeouts, secrets guard.
Release: fail-closed signing, protected workflow, verification and checksum
scripts, transition guide, checklist.

## 5. Tests actually run

| Command | Result |
| --- | --- |
| `dart format --set-exit-if-changed .` | pass |
| `flutter analyze` | no issues |
| `flutter test --coverage` | 227 passed; 58.3% of instrumented lines in the 92 files tests load (147 exist) |
| `flutter build apk --debug` / `--release` (x86_64) | pass |
| Integration tests on Android 14 x86_64 emulator | 6/6 and 1/1 passed |
| webapp `npm ci`, `tsc`, `eslint`, `vitest`, `next build`, `playwright` | all pass; 9 unit, 7 browser tests |
| `npm audit --omit=dev` | 0 |

## 6. Security and dependencies

See audit section 5 and `DEPENDENCY_LICENSING.md`. A signing keystore
(`upload-keystore.jks`) is in public git history and `key.properties.bak` was
tracked; contents were intentionally not read. Treat that key as compromised
until assessed.

## 7. Evidence

Screenshots: `docs/screenshots/android` (real emulator) and
`docs/screenshots/web`. Measured: emulator cold start median about 2.4 s,
117 MB PSS at onboarding (`PERFORMANCE.md`). No model inference, tokens/s, RAM
under load or battery figure exists: no arm64 device was available and the
Cactus library is `arm64-v8a` only.

## 8. Blockers

Production key and release (maintainer); arm64 phone for inference,
Whisper, reminders and upgrade tests; Syncfusion registration decision;
Reddit/Indie Hackers/AlternativeTo rules not readable from here.

## 9. Next priorities

1. Resolve O17 and create a production key. 2. Run the compatibility matrix on
three arm64 phones. 3. Fix the latest-release surface. 4. Finish localization
with reviewed translations. 5. Backend and PDF spikes. 6. Client-address
allow-list, streaming `finish_reason`, Dart dependency scanning.

Marketing drafts: `docs/marketing/LAUNCH_ASSETS.md`. Release readiness:
`docs/RELEASE_CHECKLIST.md`.
