# PocketLLM Lite Project Audit

Audit date: 2026-10-15. Baseline: `main` at `6504cdd`, working branch
`claude/quality-growth-pass-1`. Flutter 3.41.9 / Dart 3.11.5 on Windows 11.

This audit builds on [`V1_0_36_PRODUCT_AUDIT.md`](V1_0_36_PRODUCT_AUDIT.md),
which holds the per-feature table and its evidence. That table was not
re-derived feature by feature here. This pass re-verified the baseline, read the
network, server, tool, ingestion and web paths in full, and fixed what it found.
Anything not listed under "Verified in this pass" inherits the status and
caveats of the earlier audit.

Evidence labels: **Verified** (run or observed in this pass), **Read** (source
inspected, not executed), **Inherited** (earlier audit, not re-run),
**Not verified** (no device or access).

## 1. Verified architecture

| Layer | What is there | Evidence |
| --- | --- | --- |
| Android/Flutter app | `lib/` ~38k lines Dart. `core/` (theme, shared M3 widgets, routing), `features/` (chat, model_browser, rag, settings, onboarding, media, profile, tags, error_log, splash), `services/` (inference, network, downloads, RAG, tools, backup), `models/`, `providers/`. Riverpod 3, Hive CE, go_router | Read |
| Inference | `InferenceService` interface with Cactus (on-device GGUF), Ollama and OpenAI-compatible adapters, selected by `inference_service_factory.dart`; all generation goes through `GenerationPipeline` (tool loop capped at 5 rounds, cancellation token) | Read |
| Network boundary | `NetworkGateway` (http) and a Dio interceptor in `ModelDownloadService` both call `NetworkPolicyService.evaluateConnection`. Strict Offline blocks everything but loopback. Only direct `launchUrl` uses are in `ExternalNavigationService` and the email draft tool, and a regression test pins that | Read + test |
| Embedded server | `OpenAiServerService` on `dart:io` `HttpServer`: `/v1/models`, `/v1/chat/completions` (+SSE), `/v1/embeddings`, bearer key in secure storage, per-IP rate limit, concurrency cap | Read + test |
| Tools | `ToolCallingService`: calculator, clipboard, notes, reminders, draft_email, open_url, system_info, web_search. Confirmation required for state-changing tools; schema validation; per-tool timeouts | Read + test |
| RAG | `DocumentIngestionService` (Syncfusion PDF, TXT, MD, CSV) -> paragraph chunks -> `VectorStoreService` with keyword/semantic/hybrid retrieval | Read + test |
| Web Edition + website | `webapp/` Next.js 16 single page, hash-routed, IndexedDB, Ollama/OpenAI-compatible endpoints, Whisper via Transformers.js | Read + build + browser |
| CI | `.github/workflows/ci.yml`: format check, `flutter analyze`, `flutter test`. A `web` job was added in this pass | Read |

## 2. Baseline results (before any change)

| Check | Result |
| --- | --- |
| `dart format --set-exit-if-changed .` | pass (206 files) |
| `flutter analyze` | pass, no issues |
| `flutter test` | **142 passed, 2 failed** |
| `webapp: tsc --noEmit` | pass |
| `webapp: eslint src` | 7 errors, 0 warnings (react-hooks rules) |
| `webapp: npm audit --omit=dev` | 11 vulnerabilities (1 critical, 6 high, 4 moderate) |
| `webapp: next build` | pass, but with `typescript.ignoreBuildErrors: true` and a `metadataBase` warning |

The v1.0.38 verification report states 144 tests passed. Main was red at
`6504cdd` because two regression tests were never updated for v1.0.39 and for the
removal of the static `index.html` (finding F1).

## 3. Findings

Severity: **P0** data loss, security breach or app unusable. **P1** broken core
journey, broken CI, or a claim the product contradicts. **P2** wrong behavior with
a workaround. **P3** polish or latent risk.

### Fixed in this pass

| ID | Sev | Finding | Root cause | Fix | Regression test |
| --- | --- | --- | --- | --- | --- |
| F1 | P1 | `main` CI red: two `release_truth_test` cases fail | Test hard-coded `1.0.38+38` and read deleted `index.html` / `pocketllm-website/privacy.html` | Derive version from `pubspec.yaml`, scan current `webapp/src/features/marketing/*` | `test/regressions/release_truth_test.dart` |
| F2 | P1 | Repository README is a corrupted website hand-off note: title says "marketing website redesign", no pitch, no install steps, file-drop tree in the middle | A website package README was spliced into the product README | Rewrote README from verified features, links to real docs and the release that has APKs | `release_truth_test` (version badge must match pubspec) |
| F3 | P2 | Embedded server: if the runtime throws after the first SSE token, the connection never terminates | Handler set `statusCode` after headers were sent, got `StateError`, swallowed it and never closed the response | In-band `error` event, `[DONE]`, close; log 500 | `openai_server_service_test.dart` "runtime failure mid-stream" (reproduced: 5 s timeout before the fix) |
| F4 | P2 | Embedded server buffers a whole oversize body before rejecting, and answers 400 | `utf8.decoder.bind(request).join()` then length check | Enforce 4 MB while streaming and via `Content-Length`; 413 | "rejects request bodies over the size limit with 413" (was 400) |
| F5 | P3 | Bearer token compared with `!=` | Non-constant-time string comparison | Constant-time byte comparison | Covered by existing 401/200 tests; timing is not asserted |
| F6 | P2 | A model emitting `"id": 7` in a tool call crashes parsing | `decoded['id'] as String?` throws `TypeError`, only `FormatException` was caught | Accept only non-empty strings, otherwise generate an id | `tool_calling_service_test.dart` "tolerates non-string call ids" |
| F7 | P2 | Documented legacy `<tool_call name=".." args=".." />` adapter never parsed JSON arguments | Regex character class excluded `"`, but JSON always contains `"` | Match single-quoted or double-quoted attribute, decode HTML entities | "legacy XML adapter parses JSON arguments in either quote style" |
| F8 | P2 | Citations for TXT/MD/CSV claim `page 1` for every chunk | Plain text was modeled as a single "page" | Cite `section N`; keep real pages for PDF | `document_ingestion_service_test.dart`, `rag_service_test.dart` |
| F9 | P3 | Windows-1252 / Latin-1 text and CSV files fail with "Could not extract document text" | `File.readAsString()` is strict UTF-8 | Strip BOM, UTF-8 then Latin-1 fallback | "legacy single-byte text files are decoded" |
| F10 | P1 | Web Edition loads Google Fonts on every page view, which contradicts the privacy positioning and the Android rule against runtime fonts | `<link href="https://fonts.googleapis.com/...">` in `layout.tsx` | `next/font/google` (self-hosted at build time) | `release_truth_test` "web edition does not load runtime fonts"; browser check: only same-origin resources plus the release API call |
| F11 | P2 | Open Graph / Twitter images resolve to `http://localhost:3000` | `metadataBase` unset | Set `metadataBase`, canonical, Twitter card | Build output shows absolute `og:image` |
| F12 | P2 | Web type errors cannot fail a build | `typescript.ignoreBuildErrors: true` | Removed (tsc was already clean) | `next build` now runs TypeScript, passes |
| F13 | P1 | Critical Next.js advisories (incl. `next/og` RCE) in production dependency tree | `next@16.3.5` | `npm audit fix` -> `16.4.1`; CI fails on critical | `npm audit --omit=dev`: critical 1 -> 0 |
| F14 | P3 | Hard-coded `Colors.grey` / `Colors.amber` in markdown placeholder and star icon | Violates AGENTS.md 1.1 | Theme tokens (`outlineVariant`, `onSurfaceVariant`, `tertiary`) | `flutter analyze` |

### Open

| ID | Sev | Finding | Evidence | Recommended action |
| --- | --- | --- | --- | --- |
| O1 | P1 | GitHub "latest" release is v1.0.35 and v1.0.39 has no assets. Users following "Releases -> Latest" get a four-version-old build; 1.0.36 to 1.0.39 are all marked pre-release | Release API, 2026-10-15 | Maintainer: attach the v1.0.38 APKs (or a v1.0.40 build) to a non-pre-release, or explicitly mark v1.0.38 as latest. Needs a signing decision |
| O2 | P1 | Release APKs are debug-signed. Users cannot receive in-place upgrades from a future production-signed build | `docs/V1_0_38_VERIFICATION.md` | Maintainer: create and safeguard a production keystore. Not done here: needs credentials |
| O3 | P2 | `web_search` tool metadata says `requiresNetwork: false`, low risk, no confirmation, while its handler sends model-chosen text to Tavily. Untrusted document text can steer the query | `tool_calling_service.dart` | Mark `requiresNetwork`, `medium`, `networkScope`; consider per-call confirmation. Per-chat opt-in currently gates it |
| O4 | P2 | Marketing page fetches `api.github.com` from the visitor's browser | Browser resource list, 2026-10-15 | Fetch releases at build/ISR time and keep the embedded fallback |
| O5 | P2 | Remaining npm advisories need breaking upgrades: `sharp`, `js-yaml`, `prismjs`, `source-map-js`, `deepmerge-ts` (9 total: 4 moderate, 5 high) | `npm audit` | Evaluate `npm audit fix --force` on a branch with the web test pass; sharp is only reachable through image optimization |
| O6 | P3 | Dio follows HTTP redirects inside the adapter, so the policy interceptor and audit log see only the first hop (e.g. huggingface.co -> CDN). Strict Offline still blocks the first hop | `model_download_service.dart` | Resolve redirects manually or log the final host |
| O7 | P3 | Loopback requests, including `0.0.0.0`, are written to the persisted audit log on every call | `network_policy_service.dart` | Count loopback in memory only; drop `0.0.0.0` from the allow list |
| O8 | P3 | Embedded server binds `127.0.0.1` only. A client resolving `localhost` to `::1` fails | `openai_server_service.dart` | Also bind `::1` or document `127.0.0.1` |
| O9 | P3 | Chat completion `finish_reason` is always `stop`, never `length` | `openai_server_service.dart` | Return `length` when the token cap is hit; needs a runtime signal |
| O10 | P3 | ESLint react-hooks errors: refs read during render in chat/notes views, `openEdit` used before declaration (memories, tags) | `eslint src` | Fix and then make lint blocking in CI |
| O11 | P3 | Store art (`assets/pocketllmlite/banner main.png`, `image1.jpg`) shows the old Ollama-only UI and "100% offline. No cloud. No tracking." The product also supports optional remote runtimes | Viewed | Re-shoot assets from v1.0.38 and phrase offline claims precisely |
| O12 | P3 | GitHub repo description still says "connects to Ollama through Termux" and "Android and iOS" | GitHub API | Maintainer: update description and add `android`, `on-device-ai`, `gguf`, `privacy`, `rag` topics |
| O13 | P3 | `ota_update`, `cactus`: `cactus` Flutter repo archived upstream (July 2026); `flutter pub get` reports a discontinued package | `docs/KNOWN_LIMITATIONS.md`, pub output | Identify the discontinued package; plan backend contingency (already item 4 in the gap analysis) |
| O14 | P2 | Web Edition: with no runtime connected, chats are answered by the "Offline Sandbox", a deterministic placeholder generator. It is labelled in the model selector, setup wizard and sidebar (`model-selector.tsx`, `wizard-view.tsx`, `sidebar.tsx`), but per-message labelling in the thread was not verified | Source read | Make "no model connected" the default state with a connect prompt instead of canned replies, or stamp every sandbox message in-thread. Keeps the "no fake AI responses" rule absolute |
| O15 | P2 | `syncfusion_flutter_pdf` is not an OSI-licensed library (Syncfusion's community/commercial licensing, to be confirmed against its current terms; not verified in this pass). The repository is MIT, and the dependency would also block F-Droid-style FOSS distribution | `pubspec.yaml` | Maintainer: confirm eligibility under the current Syncfusion terms and document it in the README/NOTICE; evaluate a permissive PDF text extractor |
| O16 | P2 | Localization is advertised (`Agents.MD` 3.4, release notes) but not wired: no `localizationsDelegates`/`AppLocalizations` use outside `lib/l10n/`, and each ARB file holds 15 strings. The UI is English-only | `grep` over `lib/` | Wire delegates, extract strings feature by feature, and describe the status accurately until then (README corrected in this pass) |

### Checked and found sound

- No advertising or analytics SDK imports (existing regression test).
- All `http`/Dio construction is inside the gateway or the policy-gated download
  service; `launchUrl` appears only where the regression test expects.
- Strict Offline blocks before the per-purpose switch, so no purpose can bypass
  it. `fontDownload` is unconditionally denied.
- Tool execution order is allow-list, existence, schema validation, confirmation,
  timeout. Unknown or extra arguments are rejected.
- Embedded server authenticates before routing, rate-limits per client address,
  and caps concurrent generation.

## 4. Not verified

No physical Android device, emulator session, or model weights were available in
this pass. These remain unverified and are not claimed: on-device inference
quality and speed, first-token latency, peak RAM, battery, Whisper accuracy,
OCR on real photos, reminder delivery, low-RAM behavior, and upgrade
preservation. See [`QA_TEST_REPORT.md`](QA_TEST_REPORT.md).
