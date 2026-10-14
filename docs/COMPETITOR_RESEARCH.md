# PocketLLM Lite Competitor Research

Research date: **2026-10-15**. Extends the 2026-08-25
[`COMPETITOR_GAP_ANALYSIS_2026.md`](COMPETITOR_GAP_ANALYSIS_2026.md), which holds
the model-candidate review and is not repeated here.

Method and limits: repository facts come from the public GitHub API on the date
above. Feature statements come from each project's own repository page. Where
only third-party summaries were available the row says so. No product was
installed or benchmarked, so nothing below is a performance comparison. Reddit
and some storefronts could not be fetched.

## 1. Repository and release signals (GitHub API, 2026-10-15)

| Project | Stars | Forks | License (GitHub) | Last push | Open issues+PRs |
| --- | ---: | ---: | --- | --- | ---: |
| [PocketLLM Lite](https://github.com/PocketLLM/pocketllm-lite) | 22 | 2 | MIT | 2026-10-04 | 0 |
| [PocketPal AI](https://github.com/a-ghorbani/pocketpal-ai) | 8,647 | 955 | MIT | 2026-10-14 | 206 |
| [Google AI Edge Gallery](https://github.com/google-ai-edge/gallery) | 24,963 | 2,735 | Apache-2.0 | 2026-10-14 | 428 |
| [ChatterUI](https://github.com/Vali-98/ChatterUI) | 2,819 | 265 | AGPL-3.0 | 2026-10-05 | 12 |
| [Jan](https://github.com/janhq/jan) | 44,948 | 3,098 | not detected (`NOASSERTION`) | 2026-10-14 | 586 |
| [MLC LLM](https://github.com/mlc-ai/mlc-llm) | 23,247 | 2,170 | Apache-2.0 | 2026-10-06 | 354 |
| [GPT4All](https://github.com/nomic-ai/gpt4all) | 77,364 | 8,260 | MIT | 2025-05-27 | n/a |
| [Ollama](https://github.com/ollama/ollama) | 183,175 | 18,278 | MIT | 2026-10-14 | n/a |

Stars measure visibility, not installs. The one observation worth acting on:
PocketPal AI is the closest comparable (open source, MIT, Android+iOS, GGUF
from Hugging Face) and has roughly 390x the stars, so the gap is discoverability
and store presence far more than a missing feature.

## 2. Feature matrix

`Y` = stated on the project's own page, `N` = page does not mention it (not
proof of absence), `?` = not checked, `3P` = third-party summary only.

| Capability | PocketLLM Lite | PocketPal AI | AI Edge Gallery | Layla | Private LLM | ChatterUI |
| --- | --- | --- | --- | --- | --- | --- |
| Platforms | Android APK (iOS source, unverified) | Android, iOS/iPadOS | Android 12+, iOS 17+, macOS | Android, iOS (3P) | Apple only (3P) | Android |
| Distribution | GitHub APK, debug-signed | Play Store, App Store | Play Store, App Store, DMG, APK | Stores (3P) | App Store, paid (3P) | GitHub |
| On-device GGUF | Y (Cactus) | Y | LiteRT models, custom models | Y (3P) | Y (3P) | Y |
| HF search + download | Y, resumable, verified | Y, gated repos with token | Hugging Face LiteRT community | custom GGUF (3P) | N | ? |
| Remote / Ollama / OpenAI-compatible | Y | N (page) | N | ? | N | Y |
| Document RAG | Y keyword/semantic/hybrid | N (page) | search over media, not doc chat | ? | ? | ? |
| Speech to text | Y Whisper via Cactus | N (page) | Y Audio Scribe | ? (3P: pairs with Whisper) | ? | ? |
| Text to speech | Y platform TTS | Y Kokoro and others | ? | Y 100+ voices (3P) | ? | ? |
| Vision input | Capability-gated | N (page) | Y Ask Image | ? | ? | ? |
| Tools / agents | Y confirmed JSON tools | Y calculator, date, HTML | Y Agent Skills (URL / GitHub) | Python agents (3P) | N | ? |
| Memory | Y | ? | ? | Y (3P) | ? | ? |
| Benchmarks | Y on-device | Y with public leaderboard | Y | ? | ? | ? |
| NPU / GPU acceleration | Not exposed (unknown) | CPU, GPU, Hexagon NPU | via LiteRT | ? | ? | ? |
| Embedded API server | Y authenticated | N | N | ? | ? | ? |
| Network audit + Strict Offline | **Y** | Claims no uploads | Claims offline | ? | Claims offline (3P) | ? |
| Encrypted backup | Y | ? | ? | encrypted storage (3P) | ? | ? |
| Localization | English UI (6 ARB files, 15 strings, not wired) | 11 languages | ? | ? | ? | ? |
| Open source | MIT | MIT | Apache-2.0 | Closed (3P) | Closed (3P) | AGPL-3.0 |

Sources: [PocketPal repository](https://github.com/a-ghorbani/pocketpal-ai),
[AI Edge Gallery repository](https://github.com/google-ai-edge/gallery),
[Layla summaries](https://creati.ai/ai-tools/layla/) and
[App Store listing](https://apps.apple.com/app/id6456886656),
[Private LLM review](https://alphr.com/a-chatbot-with-privacy-in-mind-our-look-at-private-llm),
[ChatterUI repository](https://github.com/Vali-98/ChatterUI). Reports of Layla
instability are third-party user reviews and are not treated as verified.

## 3. Where PocketLLM Lite genuinely differs

Grounded in the matrix, not in marketing language:

1. **Auditable network boundary.** A single gateway, a visible per-request audit
   log, and Strict Offline as one switch. No compared project's page documents
   an equivalent user-facing audit trail.
2. **Document RAG with source citations on a phone**, with three retrieval
   modes and honest failure when no embedding model is installed.
3. **Local runtime plus bring-your-own runtime** (Ollama, OpenAI-compatible) in
   one chat surface, and an authenticated local API for other apps.
4. **Explicit "no fake success" policy**, enforced by regression tests.

Weak or unproven: store distribution, acceleration (NPU/GPU), iOS, localization
breadth, device-compatibility evidence, signed releases, and community size.

## 4. Opportunity classification

| Class | Item | Evidence | Effort | Privacy / maintenance risk |
| --- | --- | --- | --- | --- |
| Missing essential | Production-signed APK and a store listing (Play or F-Droid) | PocketPal and Gallery ship via stores; our APKs are debug-signed | Medium, needs keystore and policy work | Low |
| Missing essential | Device-compatibility matrix with measured results | Already priority 2 in the gap analysis; PocketPal publishes benchmarks to a leaderboard | Medium, needs hardware | Low |
| Missing essential | Note manager screen (tool-created notes have none) | `KNOWN_LIMITATIONS.md` | Small | Low |
| Competitive improvement | Optional, opt-in benchmark sharing as an exported file (no upload) | PocketPal leaderboard shows demand for comparable numbers | Small | Low if file export only |
| Competitive improvement | Embedded-server trusted hosts and CORS | Jan has them; ours warns | Small to medium | Reduces risk |
| Competitive improvement | Wire `AppLocalizations` into the UI, then community translations | PocketPal lists 11 | Small per language, contributor-friendly | Low |
| Competitive improvement | Hardware acceleration via a maintained backend | PocketPal lists GPU/NPU; Cactus Flutter is archived | Large | Medium |
| Differentiator | "Prove it" privacy report: exportable audit log summary | Unique audit trail | Small | Positive |
| Differentiator | Citation-faithful RAG evaluation set shipped in-repo | Our citations are verifiable; nobody compared documents it | Medium | Low |
| Differentiator | Local-API-first workflow (Termux/PC clients use phone model) | Embedded server already exists | Small docs work | Needs LAN warning kept |
| Avoid | Hosted inference, accounts, cloud sync, social sharing | Contradicts local-first positioning | n/a | High |
| Avoid | Model "marketplace" and persona store with user uploads | PocketPal PalsHub needs moderation and hosting | Large | High |
| Avoid | Auto-routing between models by task | Previously removed for lack of evidence | n/a | Medium |

## 5. Not researched

AlternativeTo, F-Droid inclusion criteria, Product Hunt policy and LM Studio,
Msty, Enclave and Maid were not individually reviewed here. See
`GROWTH_STRATEGY.md` for channel verification status.
