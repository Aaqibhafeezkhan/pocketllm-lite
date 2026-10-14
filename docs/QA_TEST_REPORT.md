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
