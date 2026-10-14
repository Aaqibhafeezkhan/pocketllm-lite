# PocketLLM Lite Growth Strategy

Written 2026-10-15. Organic growth only: no purchased stars, fake accounts,
engagement exchanges, or unverified claims. Nothing in this document has been
published, posted or sent. Every external action below is a draft for the
maintainer to approve and to send under their own account.

## 1. Positioning

**Why try it?** It is a phone-first AI chat app where you can see and control
every network connection, run GGUF models on the device, and ask questions about
your own documents with source citations.

**Why choose it over another offline assistant?** Three things the compared
projects do not document (see `COMPETITOR_RESEARCH.md`): a per-request network
audit log with a Strict Offline switch, document chat with page or section
citations, and one chat surface that works with on-device, Ollama or
OpenAI-compatible runtimes plus an authenticated local API. It is MIT licensed.

**Five-minute path:** download the v1.0.38 APK, finish onboarding, download one
small model on Wi-Fi, chat. If a step fails the app says what is missing.

**Do not claim:** "100% offline" (optional remote runtimes exist), speed or
quality numbers (none measured), iOS support (unverified), "no data leaves your
device" without qualification, or that it is faster or smarter than any
competitor.

## 2. Funnel gaps to fix before promoting

Promotion before these are fixed wastes the one launch attempt a channel gives
you.

| Gap | Evidence | Fix |
| --- | --- | --- |
| Latest release has no APK; GitHub "latest" is v1.0.35 | Release API 2026-10-15 | Roadmap item 1 |
| README was corrupted | Fixed in this pass | Done |
| Repo description and topics are stale | GitHub API | Maintainer edit (O12) |
| Banner/art shows the old UI and an absolute "100% offline" line | Viewed | Re-shoot (O11) |
| Debug-signed APKs trigger Play Protect and upgrade friction | Verification report | Production key (O2) |
| No short demo asset | Repo contents | Section 5 storyboards |

## 3. Baseline metrics (public data, 2026-10-14 UTC)

Captured with `node scripts/growth_report.mjs`. These are observations, not
targets.

| Metric | Baseline |
| --- | ---: |
| Stars | 22 |
| Forks | 2 |
| Watchers | 1 |
| Contributors (all time) | 2 |
| Open issues + PRs | 0 |
| PRs merged, last 7 days | 0 |
| Issues opened / closed, last 7 days | 0 / 0 |
| Release asset downloads, all releases | 1,573 |
| Latest release (v1.0.39) asset downloads | 0 (no assets) |
| v1.0.38 universal / arm64 / armv7 / x86_64 | 156 / 49 / 4 / 2 |
| v1.0.35 arm64 (current GitHub "latest") | 592 |
| Discussions enabled | yes |

Downloads include re-downloads, bots and mirrors. Stars are not installs.

**Proposed 90-day targets (separate from the baseline, adjust freely):** every
release carries APKs and checksums; at least 5 contributors with a merged PR;
at least 3 device-compatibility reports in the repo; median first response to
an issue under 48 hours. A star target is intentionally omitted: it is not
controllable without gaming it.

## 4. Channels (verification status)

Only the first row was verified in this pass. For every other row, confirm the
current rules on the day you post.

| Channel | URL | Audience | Cost | Status / restrictions | Content needed |
| --- | --- | --- | --- | --- | --- |
| Show HN | https://news.ycombinator.com/showhn.html | Developers | Free | **Verified 2026-10-15:** title starts "Show HN"; must be something people can try, ideally without sign-up; not for landing pages or minor releases; do not ask friends to upvote | Post (6.1), be present in comments for hours |
| r/LocalLLaMA | https://www.reddit.com/r/LocalLLaMA/ | Local-model enthusiasts | Free | Not verified (page not fetchable). Read the sidebar rules and flair requirements; disclose you are the author | Post (6.2) |
| GitHub Topics / Discussions | repo settings | GitHub browsers | Free | Own repo | Topics, description, pinned discussion |
| Awesome lists | e.g. awesome-ollama, awesome-local-ai | Developers | Free | Drafts exist in `docs/pr_submissions/`; confirm current list contribution rules and that each entry fits the list's scope | Short entry line |
| Hugging Face community / blog | https://huggingface.co | Model users | Free | Not verified | Short compatibility report, not a promo post |
| DEV Community / Hashnode | https://dev.to, https://hashnode.com | Developers | Free | Not verified | Article (6.5) |
| Product Hunt | https://www.producthunt.com | General tech | Free | Not verified; best only after store listing and a demo video exist | Listing (6.3) |
| AlternativeTo | https://alternativeto.net | People comparing apps | Free | Not verified; accepts community submissions per site flow | Description, screenshots |
| F-Droid | https://f-droid.org | FOSS Android users | Free | Likely **not eligible today** because of the PDF library licence question (O15) and a debug-signed build | n/a until resolved |
| LinkedIn | https://www.linkedin.com | Professional network | Free | Personal account post | Post (6.4) |
| YouTube | https://www.youtube.com | Tutorials | Free | Needs recorded demos | Storyboards (section 5) |
| Indie Hackers | https://www.indiehackers.com | Makers | Free | Not verified | Retrospective-style post |

## 5. Demo video storyboards (all use real behavior)

1. **"Prove it's offline" (45 s).** Airplane mode on. Open app, enable Strict
   Offline, try Hugging Face search: blocked with a reason, entry in the audit
   log. Then chat with an installed model. Shows the network boundary and the
   local runtime. Requires a device with a model installed.
2. **"Ask your PDF" (60 s).** Import a public-domain PDF, ask a question whose
   answer is on a known page, open the cited source. Then show a TXT file cited
   by section. Shows citations that can be checked.
3. **"Phone as a local API" (60 s).** Start the embedded server on loopback,
   `curl` from Termux with `stream: true`, show tokens arriving, then the
   request log. Shows the developer angle.

## 6. Draft copy (human-written style; edit before use)

### 6.1 Show HN

**Title:** Show HN: PocketLLM Lite – Android local LLM app with a network audit log

> I've been building an Android app for running GGUF models on the phone and
> chatting with my own documents. The part I haven't seen elsewhere is the
> network boundary: every outbound request the app makes (model search,
> downloads, update checks, optional web search, remote runtimes) goes through
> one policy gateway and is listed in an audit log, and Strict Offline blocks
> everything except loopback.
>
> What works: on-device GGUF via Cactus, Ollama and OpenAI-compatible
> endpoints, PDF/TXT/MD/CSV retrieval with page or section citations, Whisper
> transcription, confirmed tool calls, encrypted backups, and an authenticated
> OpenAI-compatible server you can hit from another device.
>
> What doesn't, honestly: the APKs are debug-signed, I haven't measured
> throughput across devices yet, Cactus's Flutter SDK was archived upstream so
> the backend is a risk, and iOS isn't verified. Compatibility depends heavily
> on the exact model file and phone.
>
> Repo (MIT): https://github.com/PocketLLM/pocketllm-lite — APK in Releases
> (v1.0.38). I'd most like feedback on which phones/models fail for you.

*Why it fits HN:* it is tryable, the author is present, and it leads with a
technical decision and its limits rather than adjectives.

### 6.2 Reddit (r/LocalLLaMA style; check rules and flair first)

> **I built an Android app where you can see every network request it makes
> (MIT)**
>
> Disclosure: I'm the author. PocketLLM Lite runs GGUF models on-device
> (Cactus) and can also talk to your Ollama or any OpenAI-compatible endpoint.
> It has doc RAG with citations, Whisper STT, and a local OpenAI-compatible
> server. Strict Offline mode blocks all non-loopback traffic from the app, and
> there's an audit log of what was allowed or blocked and why.
>
> I don't have good cross-device numbers yet, so I'm asking for compatibility
> reports: phone, RAM, model + quant, what happened. There's an issue template.
> Known limitations are written down in the repo.

*Why it fits:* the community values reproducible reports and dislikes
unqualified "private AI" claims, so this asks for data and states limits.

### 6.3 Product Hunt (only after store presence and a demo exist)

> **Tagline:** Local AI chat for Android with a visible network boundary
> **Description:** Run GGUF models on your phone or connect your own Ollama or
> OpenAI-compatible server. Chat with PDFs and notes with source citations,
> transcribe audio with on-device Whisper, and check the audit log to see
> exactly which connections were made or blocked. MIT licensed, no accounts, no
> ads, no analytics SDKs.
> **First comment:** what is real today, what is not (debug-signed APKs, no
> measured benchmarks yet), and what feedback you want.

### 6.4 LinkedIn

> Shipped a set of reliability fixes to PocketLLM Lite, an open-source local AI
> app for Android. Highlights: the embedded API server now terminates streams
> cleanly when a model fails mid-response, tool-call parsing no longer crashes
> on malformed model output, and document citations no longer claim "page 1"
> for plain text files. I also removed a runtime Google Fonts request from the
> web edition so the site matches the app's privacy claims. Each fix started
> with a failing test. Repo and write-up in the comments.

### 6.5 Technical article outline: "A network gateway for an on-device LLM app"

1. The problem: "offline" claims you cannot verify.
2. One chokepoint: `NetworkGateway`, purposes, and the policy table
   (`assets/network_policy.json`).
3. Strict Offline as a check before the per-purpose switch; why loopback is
   allowed and what is out of scope (OS handoffs).
4. Testing the boundary: regression test that forbids stray `launchUrl`, and
   finding that Dio redirects are only audited at the first hop (O6).
5. What it does not protect against.
6. Streaming through `GenerationPipeline`, cancellation, and the 5-round tool
   loop.

## 7. Four-week distribution calendar

| Week | Do | Done when |
| --- | --- | --- |
| 1 | Fix release/latest, repo description, topics, README art. Record demo 1 and 2. Enable a pinned "Compatibility reports" discussion | `releases/latest` has an APK; funnel gaps closed |
| 2 | Publish the architecture article on DEV/Hashnode (6.5). Submit awesome-list entries from `docs/pr_submissions/` after re-checking list rules | Article live; submissions opened by the maintainer |
| 3 | Show HN (6.1) on a weekday morning US Eastern when you can stay online. Reply to every comment | Thread active; issues triaged within 48 h |
| 4 | Reddit post (6.2) at least a few days after HN, using what HN taught you. LinkedIn (6.4). Summarize compatibility reports into the repo | Matrix seeded; growth report published |

## 8. Experiments

| Experiment | Hypothesis | Metric | How |
| --- | --- | --- | --- |
| E1 README first screen | A screenshot + one-line pitch above the fold raises release clicks | Release page views from README (GitHub traffic, repo owner only) | Compare 2 weeks before/after |
| E2 First-install success | A "pick this model" recommendation cuts support issues | Share of issues tagged `install` / first-model | Label issues, count per 10 |
| E3 Compatibility template | Structured reports are actionable | % of reports with device + model + quant | Issue form fields |
| E4 Good-first-issue labels | Labelled tasks convert visitors to PR authors | Merged first-time contributor PRs per month | `growth_report.mjs` |
| E5 Website CTA | A single "Download APK v1.0.38" button beats two | Click-through if a privacy-respecting counter is added (see section 9) | Optional |

## 9. Measurement and privacy

- No app telemetry will be added. Use GitHub's own traffic and release counts
  (public API, `scripts/growth_report.mjs`) and user-reported results.
- Website analytics are not currently installed. If added, use a cookieless,
  self-hosted or privacy-first counter, disclose it on the privacy page, and
  never load it in the app or the `#/app` workspace.
- Weekly report template: run the script, paste the table, add three lines:
  what shipped, what users reported, what we will do next week.
- Never equate stars or downloads with active users in any public statement.
