# PocketLLM Lite Execution Report

Date: 2026-10-15. Branch `claude/quality-growth-pass-1` (5 commits on top of
`main` at `6504cdd`). Not pushed, no pull request opened, no release created.

## 1. Result in one paragraph

`main` was red in CI (2 failing tests). It is green now: format clean,
`flutter analyze` clean, 151 of 151 tests pass, the web edition type-checks and
builds with TypeScript validation enabled. The pass fixed 14 verified defects
(each reproduced or observed first), closed a critical dependency advisory, and
produced the audit, QA, UX, competitor, roadmap, growth and contributor
documents. Nothing was run on a physical phone, so on-device inference quality,
performance and battery are unverified.

## 2. Commits

| Commit | Summary |
| --- | --- |
| `a66046c` | Harden embedded API server (SSE termination, 413, constant-time key), rewrite corrupted README, repair stale release tests |
| `2b9f45e` | Tool-call id crash, legacy XML adapter, section citations for text sources, Latin-1/BOM imports |
| `5756163` | Web: self-hosted fonts, `metadataBase`, type checks on, `npm audit fix`, web CI job, theme-token colors, growth report script |
| `2c7c345` | Documentation set, DEVELOPMENT.md, honest chat empty-state copy, localization wording |
| (this commit) | EXECUTION_REPORT.md |

## 3. Every code change

| Area | File(s) | Change |
| --- | --- | --- |
| Server | `lib/services/openai_server_service.dart` | In-band error + `[DONE]` + close on mid-stream failure; streaming 4 MB limit with 413; constant-time bearer comparison; 400/413/500 mapping |
| Tools | `lib/services/tool_calling_service.dart` | Non-string `id` tolerated; legacy `<tool_call>` accepts JSON in single-quoted or entity-escaped attributes |
| RAG | `lib/services/document_ingestion_service.dart`, `lib/services/rag_service.dart` | `section` metadata and citation for unpaged sources; UTF-8 BOM strip and Latin-1 fallback |
| UI copy | `lib/features/chat/presentation/widgets/chat_body.dart` | Capability-true suggestions; no Ollama-only wording |
| UI tokens | `lib/core/utils/markdown_handlers.dart`, `chat_bubble.dart` | Theme colors instead of grey/amber literals |
| Web | `webapp/src/app/layout.tsx`, `globals.css`, `next.config.ts`, `package-lock.json` | `next/font`, `metadataBase`, Twitter card, no `ignoreBuildErrors`, Next 16.3.5 -> 16.4.1 |
| CI | `.github/workflows/ci.yml` | New `web` job |
| Tooling | `scripts/growth_report.mjs` | Public-metrics snapshot |
| Tests | `release_truth_test`, `openai_server_service_test`, `tool_calling_service_test`, `document_ingestion_service_test`, `rag_service_test` | See `QA_TEST_REPORT.md` section 2 |
| Docs | README, CONTRIBUTING, DEVELOPMENT, `docs/*` | See section 2 above |

No data model, storage schema, backup format or setting key changed, so no
migration is involved. Existing text-file chunks stored before this change keep
`page: 1` metadata until the document is re-ingested (the cosmetic citation
remains for them).

## 4. Test results (this environment)

| Check | Result |
| --- | --- |
| `dart format --set-exit-if-changed .` | pass |
| `flutter analyze` | no issues |
| `flutter test` | 151 passed, 0 failed (baseline 142 passed, 2 failed) |
| `webapp: tsc --noEmit` | pass |
| `webapp: next build` | pass, TypeScript validated |
| `webapp: eslint src` | **7 errors remain** (react-hooks); CI step is non-blocking |
| `webapp: npm audit --omit=dev` | 0 critical, 5 high, 4 moderate remain (need breaking upgrades) |
| Browser: production build at 375 px | no horizontal scroll, no console output, no Google font requests |

## 5. Benchmarks

None were taken. No startup, first-token, tokens/second, RAM, battery or frame
timing measurement exists from this pass, and no performance claim is made or
should be inferred. The only timing facts: `flutter analyze` took 131.9 s cold
and 19.7 to 40.7 s warm, and the full test suite takes about 25 s, both on this
Windows host.

## 6. Not done and why

| Item | Reason |
| --- | --- |
| Device / emulator journeys, fresh-install and upgrade tests | No device or emulator session in this environment |
| Real-model inference, Whisper, OCR, reminders | No model weights or hardware |
| Production signing, GitHub release fix (O1, O2) | Needs the maintainer's keystore and a release decision; releases are explicitly out of scope without authorization |
| GitHub repo description/topics (O12) | External setting; needs the owner |
| Lighthouse, axe, Playwright | Not run; no suites exist in the repo |
| Remaining npm advisories (O5) | Require `--force`/major changes; not applied unattended |
| ESLint react-hooks errors (O10) | Left for a focused PR (task C-1) with browser checks |
| `web_search` confirmation policy (O3), Web sandbox default (O14) | Product decisions, listed in the roadmap |
| Reddit, Product Hunt, AlternativeTo policy verification | Not fetchable or not checked; marked unverified in `GROWTH_STRATEGY.md` |
| Publishing posts, opening issues, submitting to lists | Not authorized; drafts only |

## 7. Recommended next actions (in order)

1. Review and merge this branch (or cherry-pick `a66046c` first: it turns CI
   green).
2. Fix the release surface: attach the v1.0.38 APKs (or build v1.0.40) to a
   release that GitHub treats as latest, and state signing honestly (O1, O2).
3. Update the repo description and topics (O12) and re-shoot README art (O11).
4. Run the manual matrix in `QA_TEST_REPORT.md` section 5 on at least three
   phones and commit the results.
5. Open the contributor tasks C-1 to C-12 as labelled issues, a few at a time.
6. Decide O3 (web search confirmation) and O14 (sandbox default).
7. Only then spend the Show HN launch (`GROWTH_STRATEGY.md` section 6.1).

## 8. External actions prepared for approval (none executed)

- Show HN post, Reddit introduction, Product Hunt copy, LinkedIn post, article
  outline: `GROWTH_STRATEGY.md` section 6.
- Awesome-list entries: `docs/pr_submissions/` (existing drafts; re-check each
  list's rules).
- GitHub issues for tasks C-1 to C-12: `CONTRIBUTOR_GROWTH.md` section 3.
- Discussions categories and pinned post: `CONTRIBUTOR_GROWTH.md` section 4.
