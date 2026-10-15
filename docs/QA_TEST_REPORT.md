# PocketLLM Lite QA Test Report

Date: 2026-10-15. Branch `claude/quality-growth-pass-1`. Host: Windows 11,
Flutter 3.41.9 / Dart 3.11.5, Node (npm 11.11), Next.js 16.4.1.

## 1. Commands run and results

| Command | Before changes | After changes |
| --- | --- | --- |
| `dart format --output=none --set-exit-if-changed .` | exit 0, 206 files | exit 0, 206 files |
| `flutter analyze` | No issues found (131.9 s, cold) | No issues found (19.7 s) |
| `flutter test` | 142 passed, **2 failed** | **151 passed, 0 failed** |
| `cd webapp && npx tsc --noEmit` | exit 0 | exit 0 |
| `cd webapp && npx next build` | pass (types skipped by config) | pass (types validated) |
| `cd webapp && npx eslint src` | 7 errors | 7 errors (unchanged, tracked as O10) |
| `cd webapp && npm audit --omit=dev` | 11 (1 critical, 6 high, 4 moderate) | 9 (5 high, 4 moderate, 0 critical) |
| `node scripts/growth_report.mjs` | n/a | exit 0, baseline recorded in `GROWTH_STRATEGY.md` |

Baseline failures, both in `test/regressions/release_truth_test.dart`:

1. `v1.0.38 release metadata and documentation agree`: expected
   `version: 1.0.38+38`, pubspec is `1.0.39+39`.
2. `public product copy excludes disproven privacy and support claims`:
   `PathNotFoundException: index.html` (file removed in commit `32cce58`).

Test count went from 144 to 151: 7 new cases (listed below), 2 existing tests
rewritten (the previously failing ones) and 1 assertion updated.

## 2. New regression tests

| Test | Reproduced failing first? | Covers |
| --- | --- | --- |
| `openai_server_service_test`: runtime failure mid-stream terminates the SSE response | Yes, `TimeoutException` after 5 s | F3 |
| `openai_server_service_test`: rejects request bodies over the size limit with 413 | Yes, got 400 | F4 |
| `tool_calling_service_test`: tolerates non-string call ids | Yes, `type 'int' is not a subtype of type 'String?'` | F6 |
| `tool_calling_service_test`: legacy XML adapter in either quote style | Yes, 0 calls parsed | F7 |
| `document_ingestion_service_test`: text chunks carry `section`, not `page` | Updated existing assertion | F8 |
| `document_ingestion_service_test`: Latin-1 CSV is decoded | Written with the fix | F9 |
| `rag_service_test`: unpaged sources cited by section | Written with the fix | F8 |
| `release_truth_test`: web edition has no runtime third-party fonts | Written with the fix | F10 |

## 3. Browser checks (Web Edition production build)

`next start` on localhost:3100, built-in browser pane.

| Check | Result |
| --- | --- |
| Page title, `h1` | "PocketLLM Lite — Your AI, on your terms", "AI, on your terms." |
| Resource origins on load | `localhost` and `api.github.com` only (O4). No `fonts.googleapis.com` / `fonts.gstatic.com` |
| Self-hosted fonts loaded | Inter, Manrope, Instrument Serif, Caveat (`document.fonts`) |
| Console | No messages |
| 375x812 horizontal overflow | None: `scrollWidth` 375 = viewport; only a decorative background layer exceeds by 3 px |
| `og:image` in built HTML | Absolute `https://pocketllm-lite.vercel.app/...` |

Not run: Lighthouse, axe/Playwright suites, keyboard-only walkthrough, the
`#/app` workspace flows, service-worker offline behavior.

## 4. Coverage and limits

No coverage tool was run (`flutter test --coverage` was not part of this pass),
so no coverage percentage is claimed. Existing test files by area: network
policy/gateway, backup and restore, download resume and integrity, Ollama
adapters, OpenAI-compatible adapter and server, generation pipeline, tools,
RAG retrieval, ingestion, OCR adapter, transcription adapter, memory,
storage/search/export, update service, plus one widget test for compact
layout at 130% text scale.

Not physically verified (no device, no model weights in this environment):

- On-device inference output, throughput, first-token latency, peak RAM, thermal
  behavior, battery.
- Whisper transcription quality, microphone capture, OCR on real photographs.
- Reminder delivery under OEM background restrictions.
- Fresh-install, upgrade-over-existing-data and uninstall/reinstall journeys on
  hardware; the Android build was not rebuilt in this pass.
- Low-storage and low-RAM behavior.

## 5. Suggested manual test matrix

A short list a contributor with a phone can run and report (see
`CONTRIBUTOR_GROWTH.md`, task C-4):

1. Fresh install, accept defaults, download one model, send three messages,
   force-stop, reopen: history intact.
2. Enable Strict Offline, attempt a model search: blocked with a visible reason
   and an audit-log entry.
3. Import a 20-page PDF and a CSV, ask for a fact on page 12: answer cites the
   right page; a TXT source cites a section, not a page.
4. Start the embedded server on loopback, call `/v1/chat/completions` with
   `stream: true` from Termux `curl`, kill the app's model mid-stream: client
   receives an `error` event and `[DONE]`.
5. Export an encrypted backup, uninstall, reinstall, restore: chats, documents
   and settings present; wrong password is rejected.

## 6. Pass 2 results (2026-10-15)

Environment: Windows 11 host, Flutter 3.41.9 / Dart 3.11.5, Node 24.14.1,
Next.js 16.4.1, Playwright 1.64 (Chromium headless shell), Android emulator
`siderea_api34` (Android 14, x86_64, WHPX).

| Command | Result |
| --- | --- |
| `dart format --output=none --set-exit-if-changed .` | pass, 226 files |
| `flutter analyze` | no issues |
| `flutter test --coverage` | **227 passed, 0 failed** (pass 1: 151) |
| `flutter build apk --debug --target-platform android-x64` | pass, 3 m 47 s |
| `flutter build apk --release --target-platform android-x64` | pass, 80.7 MB, debug-signed |
| `flutter test integration_test/core_flows_test.dart -d emulator-5554` | **6 / 6 passed** on Android 14 (PDF pages and citations, encrypted backup, Android OCR via ML Kit, memory, tools, pipeline harness) |
| `flutter test integration_test/app_flow_test.dart -d emulator-5554` | **1 / 1 passed**: fresh install, onboarding to the first-model step to chat, overflow menu |
| `cd webapp && npx tsc --noEmit` | pass |
| `cd webapp && npx eslint src e2e` | pass (0 errors; pass 1: 7) |
| `cd webapp && npx vitest run` | 9 / 9 passed |
| `cd webapp && npx next build` | pass, TypeScript validated |
| `cd webapp && npx playwright test` (desktop + mobile) | **7 / 7 passed** |
| `cd webapp && npm audit --omit=dev` | 0 vulnerabilities (pass 1: 9) |
| `cd webapp && npm ci` | pass (clean install from the lockfile) |

### Coverage (measured, with its limits)

`flutter test --coverage` instruments only files that tests import: 92 of 147
source files, 7,199 executable lines. Of those, **58.3%** are hit (services
57.4%, core 80.3%, features 65.8%). Files never imported by a test, which
includes many UI screens, are not in the denominator, so this overstates
whole-app coverage. Lowest services: `local_inference_service.dart` 0%,
`audio_recording_service.dart` 1%, `rag_service.dart` 10%,
`audio_transcription_service.dart` 24%, `update_service.dart` 30%,
`model_download_service.dart` 42%.

### What the emulator runs prove, and what they do not

| Proven on a real Android 14 runtime | Not proven |
| --- | --- |
| The real app starts from a fresh install, shows onboarding, the new first-model step and the compact chat bar | On-device model inference (the Cactus library is `arm64-v8a` only; no arm64 device was available) |
| PDF ingestion with page citations, encrypted backup rejection/restore, ML Kit OCR on generated images | Whisper, microphone capture, reminders and OEM background behavior |
| Cold start about 2.4 s median and 117 MB PSS at onboarding (emulator, see `PERFORMANCE.md`) | Download of a real catalog model end to end on a device |
| | Upgrade over an existing install and uninstall/reinstall/restore on hardware |

The "local model loads, streams through the pipeline" integration case uses an
injected backend harness, not real weights. It verifies the pipeline, not a
model.

### New tests added in pass 2

| Area | Tests |
| --- | --- |
| Network policy and redirects | loopback rules (0.0.0.0, lookalike hosts, IPv6), Strict Offline bypass attempts, persisted-log filtering, download-service redirect cases (follow, blocked hop, downgrade, loop), gateway redirect cases (blocked hop, credential drop, downgrade) |
| Tools | `web_search` classification, denial and missing confirmer, Strict Offline pre-block, oversized query, injected extra argument, confirmed request body; confirmation dialog widget tests including 130% text scale |
| Embedded API | Host rebinding, origin allow-list, preflight, auth header, unauthenticated flood limit, malformed JSON, body and generation timeouts (408/504, SSE timeout event), `finish_reason`, IPv6, origin parser |
| Documents | PDF page order and citations on a generated three-page PDF, backend swap, no-text PDF, malformed PDF; RAG evaluation corpus (hit@3 1.00, MRR 1.00 on a synthetic corpus) |
| UX | onboarding page (device-aware list, failure and retry, download progress, cancel, alternatives, 130% text), chat top bar and sheet (360 dp at 100/130/200%), notes screen, language picker, locale fallback |
| Privacy | compatibility-report allow-list, no-committed-secrets guard; web: no third-party origins, no localhost probe, no scripted reply without opt-in |
