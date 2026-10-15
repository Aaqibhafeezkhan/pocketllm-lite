# Competitive research and integration notes (Phase 3)

Method: public READMEs and public web search only. REA was not pointed at any
competitor binary: the public source and documentation were enough for the
questions below, and nothing was decompiled or copied. No proprietary code or
assets were used.

## What was found

| Project | License | Relevant observations (from its README) |
| --- | --- | --- |
| [PocketPal AI](https://github.com/a-ghorbani/pocketpal-ai) | MIT | GGUF via llama.cpp; add a model from Hugging Face or local storage; benchmark page with tokens/sec and memory; three-step onboarding (install, download, load); "Pals" personas; small tool set; optional opt-in leaderboard sharing. |
| [Google AI Edge Gallery](https://github.com/google-ai-edge/gallery) | Apache-2.0 | Task-shaped entry points (Ask Image, Audio Scribe, Prompt Lab, AI Chat); model list plus custom models from Hugging Face; per-device benchmark runs; labelled experimental beta. |
| [ChatterUI](https://github.com/Vali-98/ChatterUI) | AGPL-3.0 | Local mode and remote mode side by side; "import vs. use in place" choice for model files; quantization advice per SoC; character cards. AGPL means its code must not be reused here. |

Takeaways that map to PocketLLM:

1. Competitors that load GGUF say so plainly. PocketLLM's runtime loads only
   Cactus bundles, so the honest framing (now in the README and model screens)
   matters more than for them.
2. A visible benchmark (tokens/sec, memory) is table stakes. PocketLLM has a
   benchmark screen; real-device numbers are still missing (see the Phase 3
   report).
3. Task-shaped entry points convert better than a blank chat. Share to
   PocketLLM is the first such entry point; "Summarize this" and "Ask about
   this" are exactly that shape.
4. Opt-in sharing of benchmark numbers is a growth mechanism that does not
   require tracking. Not built; would need explicit consent UI.

## Limits of this research

* Reddit was reachable only through third-party mirror snapshots in search
  results. Nothing there confirmed specific feature requests. The only
  recurring claims were that Android local-LLM apps lag iOS and that RAM is the
  usual cause of failed loads. Treat these as anecdotes, not data.
* Dribbble and Pinterest searches returned service listings and UI kit pages,
  not usable references for a model picker. No design was copied. The UI
  decisions in this phase follow the existing Material 3 rules in `AGENTS.md`.

## Integration investigation (not built)

Current tool registry (`lib/services/tool_calling_service.dart`): calculator,
clipboard, notes, reminders, draft_email, open_url, system_info, web_search.
Network-using tools are marked `requiresNetwork` and go through
`NetworkPolicyService`, so Strict Offline Mode already blocks them.

| Idea | Feasibility | Notes and guardrails |
| --- | --- | --- |
| Website Reader | Medium | A tool that fetches one user-supplied URL, strips it to text, and passes it to the model. Must go through `NetworkGateway` with an explicit purpose, honour Strict Offline, cap bytes, refuse non-http(s) and private/loopback addresses unless the user allows them, and show the URL before fetching. Share-a-link is the natural entry point and would need a confirm step. No background fetching. |
| Calendar / Reminders | Reminders exist. Calendar needs a new permission | Creating events can use the Android calendar insert intent, which needs no permission and lets the user confirm. Reading the calendar needs `READ_CALENDAR` and is better left out until there is a clear need. |
| GitHub connector | Low priority | Needs OAuth or tokens the app would store. Read-only public-repo reading is already possible through Website Reader plus raw URLs. A token-based connector should wait for a proper secret-storage review. |
| Tool Hub (user-selectable tools) | Medium | The registry already has the shape. Missing pieces: per-tool enable switches, per-tool network disclosure, and a visible log of every tool call. The five-iteration limit in `AGENTS.md` should stay. |

None of these use private app APIs, accessibility automation or hidden network
traffic, and none are enabled by default.
