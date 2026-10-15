# Phase 3 execution report

Branch `claude/quality-growth-pass-3`, created from `claude/quality-growth-pass-2`.
Date of work: 2026-10-15. Nothing was pushed, merged into `main`, published,
or changed in GitHub settings. No credentials were rotated.

Read this first: **no real model token was generated in this phase.** Model
download, install, listing and load were verified on an emulator; generation
needs an arm64 phone, which was not available. Every claim below states the
level at which it was verified.

## 1. Signing incident assessment

Full detail: [SIGNING_INCIDENT.md](SIGNING_INCIDENT.md). Method: public,
non-secret evidence only. The keystore and the `.bak` properties file were
never read, printed or copied.

* `upload-keystore.jks` (added 2025-12-29) and `android/key.properties.bak` are
  still reachable in the public history of `origin/main`. Whether the backup
  held real passwords is unknown.
* Signing certificates of every sampled public release APK were read from the
  APK Signing Block. All are Android **debug** certificates, from two
  different machines (before and after v1.0.10). No release is signed with a
  recognisable production identity, and none is on Google Play (store page
  404).
* Consequence: users have no publisher identity to rely on, and the signer has
  already changed once, so some upgrades could not be applied in place.
* Done in code: fail-closed release signing, protected-secret release
  workflow, APK signature verification script (pass 2), and a CI secret guard
  (`scripts/ci/check-secrets.mjs`) added in this phase.
* Not done, by instruction: history rewrite, deleting releases, rotating
  anything. APK key rotation (v3 lineage) only works on Android 9+, so a
  migration plan must offer a fallback for older versions; see M4.

## 2. Code changes (this phase)

| Area | Change | Commit |
| --- | --- | --- |
| Model loading | Root cause of "error when downloading or loading a model": the app accepted only GGUF-style layouts while the runtime and its catalog use Cactus bundles (`config.txt` + `.weights`). A single `ModelBundleValidator` now decides what is runnable, and is used by download, install, scan, load, Whisper detection and the store. Archive junk (`__MACOSX`, `._*`) is ignored. GGUF files are recognised, explained and never reported as loadable. | `95bb47d` |
| Honest UX | Model detail screen explains why GGUF cannot run on-device and offers a validated, copyable `ollama run hf.co/...` command. Web copy corrected. | `3ee1e0d` |
| Probe tool | `tool/device_inference_probe.dart` (download, install, load, generate, cancel; Whisper mode). | `828f917` |
| Security | Signing incident document, CI secret guard. | `5e15a07` |
| Share | Share to PocketLLM (section 8 of this report and [SHARE_TO_POCKETLLM.md](SHARE_TO_POCKETLLM.md)). | `d953c95` |
| Docs | README, known limitations and release notes no longer claim on-device GGUF; research notes. | `fd9f49f` |

## 3. REA and competitor research

Full detail: [COMPETITIVE_RESEARCH_AND_INTEGRATIONS.md](COMPETITIVE_RESEARCH_AND_INTEGRATIONS.md).

* REA is installed for Claude Code and its tools are available. I did **not**
  use it on competitor packages: the public READMEs answered the questions
  (formats, onboarding, benchmarks, licensing) without decompiling anything, so
  no proprietary code or assets were touched. REA is not bundled in the app.
* PocketPal AI (MIT), Google AI Edge Gallery (Apache-2.0) and ChatterUI
  (AGPL-3.0, so no code reuse) were read from public READMEs.
* Reddit, Dribbble and Pinterest could only be reached through search results
  (mirrors and listings). They produced no reliable feature-request data or
  usable UI references. That limitation is recorded rather than papered over.

## 4. Real-device evidence

Environment: Android 14 x86_64 emulator with ARM translation
(`libndk_translation`). **This is not a phone.**

| Item | Result | Level |
| --- | --- | --- |
| Catalog bundle download, extract, validate, install | Worked | Emulator, real network |
| Installed model listed and loadable (`initContext`) | Worked under translation | Emulator |
| Whisper bundle download, detection, init | Worked | Emulator |
| Token generation | **Not verified.** The translated process died with SIGILL right after load. This is a translator limitation, not evidence about phones. | Blocked |
| Load time, first token, tok/s, peak RAM | **Not measured** | Blocked |
| OCR, reminders, backup/restore on a phone | **Not verified** | Blocked |
| Share intents (text, file, denied, warm start) | Verified, see section 8 | Emulator |

An arm64 phone is needed for the rest. The probe is ready:
`flutter build apk --release --target-platform android-arm64 -t tool/device_inference_probe.dart`
then read `PROBE` lines from logcat.

## 5. Test results

All run on 2026-10-15 on the Windows host.

| Check | Result |
| --- | --- |
| `flutter analyze` | No issues |
| `dart format --set-exit-if-changed lib test tool` | 235 files, 0 changed |
| `flutter test` | **260 passed, 0 failed** (baseline from pass 2 was 227; +33) |
| Web `tsc --noEmit` | Clean |
| Web `eslint .` | Clean |
| Web Vitest | 9 passed |
| Web production build | Succeeds |
| Web `npm audit --omit=dev` | 0 vulnerabilities |
| Playwright (desktop + mobile) | 7 passed, 2 skipped (screenshot generators, by design) |

Not re-run in this phase: the Android `integration_test` suite from pass 2,
and a release APK build. Say so rather than assume.

## 6. Performance

No new performance numbers were produced this phase. The only measured figures
remain the emulator cold-start and memory numbers in [PERFORMANCE.md](PERFORMANCE.md),
which are regression guards, not phone figures. Inference speed is unmeasured.

## 7. Licensing and security decisions

* ChatterUI is AGPL-3.0: no code, assets or structure copied.
* PocketPal and AI Edge Gallery were consulted for product patterns only.
* Share intake accepts only `content://`, refuses the app's own FileProvider,
  caps sizes while copying, restricts to PDF/TXT/MD/CSV, and deletes copies on
  exit or after 24 h. No automatic network access.
* PDF extraction dependency licensing: unchanged from pass 2
  ([DEPENDENCY_LICENSING.md](DEPENDENCY_LICENSING.md)); the decision there still
  needs the maintainer.
* The Supabase public anon key used for the Cactus catalog is in app source.
  It is a public client key by design; it was not changed.

## 8. Share to PocketLLM

Implemented end to end: manifest filters, native intake and copy, validation
policy, review screen with Summarize / Ask / Save to knowledge base, cleanup,
tests and docs. Verified on the emulator: text share (cold and warm), real file
share through the system Files app, denied access, cleanup after leaving.
**Summarize and Ask were not exercised with a real model.** With no model
ready, the screen tells the user and routes to model setup (widget-tested).

Not implemented: images, Office documents, automatic link fetching. Website
Reader, Calendar, GitHub connector and Tool Hub were investigated and
documented, not built.

## 9. Release readiness

**Not ready for a production-signed release.**

* Signing: only debug-signed builds can be produced from this checkout. A
  production key and a tested upgrade path do not exist (M2 to M4).
* On-device generation is unverified on real hardware.
* "Proper new release, not pre-release": I cannot publish, and a release signed
  with a debug key should not be presented as production. The workflow and
  checklist are ready; GitHub's `latest` badge still points at the older
  v1.0.35 until a maintainer publishes.
* Branches: nothing was merged. The local and remote branches
  (`claude/quality-growth-pass-1..3`, `design/reference-match`,
  `codex/new-feature-updates`, older `Mr-dark-debug/*`, web branches) contain
  overlapping history, and merging them is a maintainer decision that pass 1
  already opened as PR 360. Pass 3 sits 26 commits ahead of `main`.
* Phase 2 items still open: a trusted client-address allow-list for the
  embedded API server, and extraction of more UI strings for localization (six
  languages exist but cover only core strings).

## 10. Maintainer actions and next five engineering tasks

Maintainer actions (from [SIGNING_INCIDENT.md](SIGNING_INCIDENT.md)):

| # | Action |
| --- | --- |
| M1 | Compare your copy of the keystore's fingerprint with `f11e9769…` and `f8821bb3…` (needs the private file) |
| M2 | Generate the production keystore |
| M3 | Add protected secrets and the `release` environment |
| M4 | Choose and test the upgrade method (v3 rotation only works on Android 9+) |
| M5 | Decide on Google Play |
| M6 | Decide on history rewrite |
| M7 | Enable secret scanning and push protection |

Also: review and merge or close PR 360 and the stale branches, and decide the
PDF dependency licensing question.

Next five engineering tasks:

1. Run the device probe on an arm64 phone; record load, first-token, tok/s and
   RAM into `PERFORMANCE.md`.
2. Exercise Summarize and Ask from the share screen with a real loaded model,
   plus PDF and `SEND_MULTIPLE`, on that phone.
3. Add the trusted client-address allow-list to the embedded API server.
4. Extract the remaining UI strings for localization and get reviews for at
   least one non-English language.
5. Build the Website Reader tool behind `NetworkGateway` with an explicit
   per-fetch confirmation, using shared links as the entry point.
