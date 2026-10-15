# Launch assets (drafts, not published)

Prepared 2026-10-15. Nothing here has been posted, submitted or applied to
GitHub. Every factual claim in the drafts appears in the claims register
(section 1) with its evidence. Do not add claims that are not in the register.

## 1. Claims register

| Claim | Evidence | Status |
| --- | --- | --- |
| All app-managed network calls go through one policy gateway with an audit log; Strict Offline blocks non-loopback traffic | `network_gateway.dart`, `network_policy_service.dart`, tests in `test/core` | Verified by tests |
| Redirects are evaluated per hop (downloads and gateway GET) | `model_download_service_test.dart`, `network_gateway_test.dart` | Verified by tests |
| The web landing page and a fresh app load make no third-party requests and no localhost probes | Playwright `privacy.spec.ts` | Verified in Chromium |
| `web_search` asks first and shows destination and the exact query | `tool_calling_service_test.dart`, `tool_confirmation_dialog_test.dart` | Verified by tests |
| The local API enforces bearer auth, Host and Origin rules, timeouts | `openai_server_service_test.dart` (20 tests) | Verified by tests |
| Citations name a page (PDF) or section (text) | `pdf_ingestion_test.dart`, `rag_service_test.dart` | Verified by tests |
| Keyword retrieval hit@3 1.00 on a 12-question synthetic corpus | `rag_eval_test.dart` | Measured; regression guard, not a quality claim |
| Onboarding can download a recommended model on the device | `first_model_setup_page_test.dart` (fake download service) | UI flow verified; **a real model download was not run** |
| App starts to first frame in about 2.4 s | `PERFORMANCE.md` | Emulator only |
| Runs GGUF models on the phone | Cactus integration, `arm64-v8a` only | **Not verified on hardware in this repository's evidence** |
| "100% offline" | n/a | **Do not claim**: optional remote runtimes, downloads and search exist |
| Any speed, battery or quality number for a model | n/a | **None measured** |
| Signed, production-grade releases | n/a | **False today**: APKs are debug-signed |

## 2. GitHub presentation

**Repository description (proposal, 220 characters):**

> Local-first AI chat for Android: GGUF models on your phone, or your own Ollama/OpenAI-compatible server. Document Q&A with citations, a visible network audit log and Strict Offline mode. MIT.

**Topics (15 max, replace the stale set):**
`android`, `flutter`, `local-llm`, `on-device-ai`, `gguf`, `ollama`, `rag`,
`privacy`, `offline-first`, `llama-cpp`, `openai-compatible`, `whisper`,
`mobile-ai`, `self-hosted`, `open-source`.
Remove `flutter-desktop`, `ollama-gui`, `ollama-ui` unless desktop is verified.

**Social preview image (1280 x 640):** left half a real screenshot of the
onboarding "Get your first model" step from `docs/screenshots/android`, right
half the one-line pitch. Do not use the old banner; it shows the previous UI and
an unqualified offline claim.

**Release description for the next APK release (draft, fill in after build):**

```markdown
## PocketLLM Lite vX.Y.Z

### Install
Download `PocketLLM-Lite-vX.Y.Z-arm64-v8a.apk` (most phones from 2017). Verify it
against `SHA256SUMS.txt`. Only the arm64-v8a build contains the on-device model
runtime; armeabi-v7a and x86_64 builds work with a remote server only.

### What changed
- First-launch step to download a model that fits your phone, or use your own server
- Compact chat bar with a model picker; secondary actions in a menu
- Notes screen for notes the assistant saved
- Language picker (Spanish, Hindi, Japanese, Korean, Chinese are not yet reviewed)
- Local API: Host and Origin checks, timeouts, IPv6 loopback
- Web search asks first and shows the exact query and destination
- Redirects are policy-checked per hop; 0.0.0.0 is no longer treated as local
- Fixes: tool-call parsing, text-file citations, Latin-1 imports, API stream hangs

### Known limitations
Signed with: <state the certificate honestly>. See docs/KNOWN_LIMITATIONS.md.
Upgrading from a build signed with a different key requires a backup and reinstall
(docs/RELEASE_SIGNING.md).
```

## 3. README additions (ready when screenshots are final)

- Lead with one sentence and the real onboarding screenshot.
- A "Compatibility" table filled only from submitted reports, with device,
  model, quantization and measured result; empty until reports exist.
- A "Verify our claims" box linking to the three Playwright and unit tests that
  prove the network boundary, so skeptics can run them.

## 4. Posts

### Show HN (best after a signed release exists)

**Title:** Show HN: A local-LLM Android app where you can audit every network request

> I built an Android app for running GGUF models on the phone and asking
> questions about your own documents. The part I care most about is that the
> network boundary is testable: every outbound request goes through one gateway,
> is listed in an audit log, and Strict Offline blocks everything except
> loopback. Redirects are checked per hop, and the web edition has a test that
> fails if its landing page contacts a third party.
>
> It also exposes an authenticated OpenAI-compatible API on loopback with Host
> and Origin checks, so other apps on the device can use the same model.
>
> Honest limits: the APKs are debug-signed until I set up a production key, I
> don't have a device benchmark matrix yet (the app can produce a report you can
> paste into an issue), the inference SDK I use is archived upstream, and only
> the arm64 build can run local models.
>
> Code (MIT): https://github.com/PocketLLM/pocketllm-lite. I'd most like
> compatibility reports: phone, model, quant, what happened.

*Why it works:* it is a technical claim the reader can falsify, limitations come
first, and there is a concrete ask.

### Reddit (r/LocalLLaMA style; read the rules and flair first)

> **Open-source Android app with an auditable network layer, plus a
> "compatibility report" button (no upload)**
>
> Disclosure: I'm the author. PocketLLM Lite runs GGUF on-device (arm64) or talks
> to your Ollama/OpenAI-compatible server. Doc RAG with page/section citations,
> Whisper, confirmed tool calls. After a benchmark run there's a button that
> copies hardware facts and speed figures to the clipboard (no prompts, nothing
> uploaded) so people can report what actually works on their phone. I don't have
> numbers yet and would rather collect real ones than guess.

### DEV / Hashnode article outline (publish once, cross-post with canonical link)

**Title:** Making "offline" testable: a network gateway for an on-device LLM app

1. The problem with unverifiable privacy claims.
2. One gateway, purposes, and a policy file; why redirects are the usual hole
   (per-hop evaluation, HTTPS-only, credentials dropped cross-host).
3. Strict Offline as a check that runs before any per-purpose rule; why
   `0.0.0.0` is not loopback.
4. Tests that make the claim falsifiable (Dart unit tests; a Playwright test
   that records every request origin).
5. Tool calls: classify, confirm, show destination and exact arguments.
6. What this does not defend against.

### LinkedIn

> Shipped the second quality pass on PocketLLM Lite, an open-source local AI app.
> Highlights: redirects are now policy-checked hop by hop, a stray 0.0.0.0
> allowance is gone, web search asks first and shows the exact query, the local
> API checks Host and Origin, and the web edition has a browser test that fails
> if its landing page talks to a third party. I also found a signing keystore in
> the public git history, so the next release is waiting on a new key rather
> than shipping something I can't stand behind. Write-up in the comments.

### Product Hunt (only after a store-quality listing and video exist)

**Tagline:** Local AI for Android with a network audit log
**Description:** Run GGUF models on your phone or connect your own server. Ask
questions about your documents with page citations, see every network request
the app makes, and switch on Strict Offline. MIT licensed, no accounts, no ads,
no analytics SDKs.
**First comment:** what is real (list), what is not (debug-signed, no benchmark
matrix), and what feedback you want. Do not ask for upvotes; ask people to try
it and comment.

## 5. Demo scripts (record on an arm64 phone with a small model installed)

1. **Prove the boundary (45 s).** Settings > Privacy: enable Strict Offline.
   Try a Hugging Face search: blocked with a visible reason. Open the audit log:
   the blocked entry is there. Disable it, search works. Voiceover states what
   Strict Offline does and does not cover.
2. **Ask your PDF (60 s).** Import a public-domain PDF, ask a question whose
   answer is on a known page, open the cited page. Then a TXT file: cited by
   section.
3. **First model in under five minutes (90 s, honest timer on screen).** Fresh
   install, onboarding to Find models, download the smallest suggestion on
   Wi-Fi, first reply. Show the real elapsed time, whatever it is.
4. **Report what works (30 s).** Run the benchmark, tap Copy compatibility
   report, paste into the issue form.

## 6. Submission checklist (per channel)

| Channel | Verified URL | Needed assets | Stage | Measure |
| --- | --- | --- | --- | --- |
| Show HN | https://news.ycombinator.com/showhn.html | Signed APK, README with screenshots, post text | After signed release | Issues and compatibility reports opened, not points |
| rafska/awesome-local-llm | https://github.com/rafska/awesome-local-llm | One-line entry | After README screenshots | Referrer traffic in GitHub Insights (owner only) |
| DEV / Hashnode | https://dev.to, https://hashnode.com | Article, diagram | Anytime | Reads, replies, issue links |
| Product Hunt | https://www.producthunt.com/launch | Listing, 60 s video, personal account | After signed release and video | Visits and comments |
| AlternativeTo | https://alternativeto.net | Description, 3 screenshots, account | After release | Referral clicks |
| F-Droid | https://f-droid.org/docs/Inclusion_Policy/ | FOSS-only build | **Not eligible yet** | n/a |
