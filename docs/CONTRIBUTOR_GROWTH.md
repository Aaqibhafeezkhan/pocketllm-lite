# Contributor Growth Plan

Written 2026-10-15. Nothing here has been posted to GitHub: the issue drafts in
section 3 are for the maintainer to open, and none should be opened just to make
the tracker look busy.

## 1. Audit of the current contributor experience

| Item | State on 2026-10-15 | Action |
| --- | --- | --- |
| README | Was corrupted; now a product README with a source-build section | Done in this pass |
| `CONTRIBUTING.md` | Good: checklist, AI-claims rule, security routing. Setup block is short | Link `DEVELOPMENT.md` |
| `DEVELOPMENT.md` | Did not exist | Added in this pass (setup, architecture diagram, rules, release checklist) |
| `CODE_OF_CONDUCT.md`, `SECURITY.md` | Present | None |
| Issue forms | `bug_report.yml`, `feature_request.yml`, blank issues disabled | Add a device/model compatibility form (task C-4) |
| PR template | Present | None |
| CI | Format, analyze, test; web job added in this pass | Keep lint non-blocking until O10 is fixed |
| Labels / tracker | 0 open issues and PRs; `good first issue` links exist in docs but no issues are known to carry them | Open the tasks in section 3, label them |
| Discussions | Enabled | Create the structure in section 4 |
| Roadmap | Internal docs only | `FEATURE_ROADMAP.md` is public; link it from README |
| Contributors | 2 all-time (GitHub API) | Section 5 |

Which entry points are most likely to work:

- **Device and model compatibility reports** are the highest-value, lowest-skill
  contribution: they need only a phone and fill a documented evidence gap.
- **Documentation fixes and screenshots** need no code and match known gaps.
- **Localization** is a weaker entry point *today*: strings are not extracted
  or wired (O16). It becomes a good one after task C-8.
- **Accessibility reports** (TalkBack, large text) are valuable and need a phone.
- **External integrations** (new providers) carry maintenance and privacy
  review cost; require an issue discussion first.

## 2. Task format

Each task: difficulty (Starter, Intermediate, Advanced), context, location,
acceptance criteria. Pick ones that are independent and testable.

## 3. Ten scoped tasks

### C-1. Fix remaining ESLint react-hooks errors in the Web Edition (Starter)
Context: `npx eslint src` reports 7 errors (O10). Refs are read during render
in two views and `openEdit` is referenced before it is declared in two others.
Location: `webapp/src/features/app/chat/chat-view.tsx`, `notes/notes-view.tsx`,
`memories/memories-view.tsx`, `tags/tags-view.tsx`.
Done when: `npx eslint src` exits 0, `npx tsc --noEmit` passes, and behavior is
unchanged in the browser. Then remove `continue-on-error` from the CI lint step.

### C-2. Note manager screen (Intermediate)
Context: the `notes` tool saves persistent notes but nothing lists them.
Location: `StorageService.getLocalNotes` / `createLocalNote` in
`lib/services/storage_service.dart`; add a screen under
`lib/features/settings/presentation/screens/`; register in `lib/core/router.dart`.
Done when: notes can be viewed, copied and deleted; empty state uses
`M3EmptyState`; uses `M3AppBar` and theme tokens; a widget test covers the empty
and populated states; included in encrypted backups (verify existing test).

### C-3. Stop persisting loopback requests in the network audit log (Starter)
Context: every loopback call is saved to the Hive-backed log, and `0.0.0.0` is
treated as loopback (O7).
Location: `lib/services/network_policy_service.dart`, `isLoopback`,
`evaluateConnection`; tests in `test/core/network_policy_test.dart`.
Done when: loopback decisions are not written to the persisted log (or are
counted in memory only), `0.0.0.0` is not allowed, and tests assert both.

### C-4. Device and model compatibility report form (Starter)
Context: compatibility depends on device, file and quantization; reports need
structure.
Location: `.github/ISSUE_TEMPLATE/`; link from `README.md` and
`docs/KNOWN_LIMITATIONS.md`.
Done when: a YAML form collects device, Android version, RAM, ABI, app version,
model repo + file + quant, context size, outcome (loaded / failed / crashed),
tokens per second if shown, and notes; blank issues remain disabled.

### C-5. Redirect-aware download audit (Intermediate)
Context: Dio's interceptor sees only the first hop of a redirected download
(O6).
Location: `lib/services/model_download_service.dart` (interceptor and the four
`_dio.download` calls); tests in `test/services/model_download_service_test.dart`.
Done when: the final host is evaluated against policy or logged in the audit
entry, with a test using a local server that redirects to a second loopback port.

### C-6. Embedded server trusted hosts and CORS allowlist (Intermediate)
Context: the server warns on LAN use but has no allowlists.
Location: `lib/services/openai_server_service.dart`; settings UI in
`lib/features/settings/presentation/screens/` (server section); tests in
`test/services/openai_server_service_test.dart`.
Done when: an allowlist of origins and an optional list of client addresses are
configurable, rejected requests return 403 and appear in the request log, and
defaults keep current loopback behavior.

### C-7. Server `finish_reason: "length"` (Advanced)
Context: the response always reports `stop` (O9).
Location: `lib/services/openai_server_service.dart`, `lib/services/generation_pipeline.dart`,
`lib/services/inference_service.dart` (metrics).
Done when: when the runtime stops because the token cap was reached, both the
streaming and non-streaming responses report `length`; no change when a runtime
cannot tell (documented). Tests use a fake inference that reports the cap.

### C-8. Wire localization (Advanced, then splits into Starter tasks)
Context: ARB files exist but no code uses `AppLocalizations` (O16).
Location: `lib/main.dart` (`MaterialApp` delegates and `supportedLocales`),
`lib/l10n/*.arb`, `l10n.yaml`.
Done when: delegates are registered, the 15 existing keys are used by their
screens, a locale-override setting exists or the device locale is respected, and
a test pumps a screen under `Locale('es')`. Follow-up tasks: extract one feature
screen per PR.

### C-9. RAG evaluation corpus (Intermediate)
Context: retrieval quality changes cannot be measured today.
Location: new `test/fixtures/rag_eval/` (small CC0 or public-domain texts),
`test/services/rag_retrieval_modes_test.dart` for patterns.
Done when: 3 documents, 15 questions with the expected source section, a test
that reports hit-rate@3 for keyword mode (semantic needs an embedding runtime
and is out of scope), license notes for each fixture, and no network use.

### C-10. TalkBack and large-text audit of one screen family (Starter)
Context: only the model prerequisite dialog has a compact large-text widget
test.
Location: `test/widgets/model_prerequisite_dialog_test.dart` as the pattern;
screens under `lib/features/`.
Done when: for one family (chat, settings, or model browser) there is a widget
test at 360 x 640 with `textScaler` 1.3 that finds no overflow, plus a list of
unlabeled interactive widgets with fixes for each.

### C-11. Marketing site: fetch releases at build time (Starter)
Context: the visitor's browser calls `api.github.com` (O4).
Location: `webapp/src/features/marketing/releases-data.ts` and
`marketing-pages.tsx`.
Done when: the page renders release data produced at build time, keeps the
embedded fallback, and the browser's resource list shows only same-origin
requests.

### C-12. Web Edition: no canned replies by default (Intermediate)
Context: the "Offline Sandbox" answers when no runtime is connected (O14).
Location: `webapp/src/lib/services/inference/inference-router.ts`,
`webapp/src/features/app/settings/wizard-view.tsx`,
`webapp/src/features/app/chat/model-selector.tsx`.
Done when: with no runtime configured the composer shows a connect-a-model
prompt instead of sending to the sandbox, existing sandbox chats remain
readable, and the setup wizard no longer presents the sandbox as a runtime
choice (or labels every sandbox message in-thread).

## 4. GitHub Discussions structure

| Category | Format | Purpose |
| --- | --- | --- |
| Announcements | Announcement | Releases, with checksums and what changed |
| Compatibility reports | Open-ended | Device + model results (links to form) |
| Q&A | Question/Answer | Setup help, answer marking |
| Ideas | Open-ended | Proposals before they become issues |
| Show and tell | Open-ended | Use cases, workflows |

Pin one post: "How to report a model that does not load".

## 5. Contributor and maintainer process

- **Triage:** first response within 48 hours, even if only "reproduced" or "need
  device details". Label with area (`android`, `web`, `docs`, `rag`, `network`)
  and difficulty. Close duplicates with a link.
- **Review:** one maintainer approval; reviews state the next action. Require a
  regression test for bug fixes and evidence (screenshot, device report) for UI
  or native claims, matching `CONTRIBUTING.md`.
- **First PRs:** thank in the thread, merge small docs fixes quickly, avoid
  rewriting a newcomer's code in review comments.
- **Recognition:** list contributors by name in release notes under each
  version, and keep an `ACKNOWLEDGEMENTS` section in the README for
  non-code contributions (device reports, translations, docs).
- **Engagement:** invite reporters to try the fix before closing. Do not tag
  issues `good first issue` unless a task has context and acceptance criteria
  like the ones above.
- **Metrics:** the weekly snapshot from `scripts/growth_report.mjs`: merged PRs,
  first-time contributors, median time to first response.

## 6. Status after pass 2 (2026-10-15)

Do not open issues for tasks marked Done. Open the ones marked Open or Partly,
a few at a time.

| Task | Status | Evidence |
| --- | --- | --- |
| C-1 ESLint react-hooks | **Done** | `npx eslint src` exits 0; CI lint is blocking |
| C-2 Note manager | **Done** | `notes_screen.dart`, storage update/delete, tests |
| C-3 Loopback audit noise | **Done** | not persisted; 0.0.0.0 not loopback; tests |
| C-4 Compatibility report form | **Done** | issue form, in-app report copy, `compatibility_report_test.dart` |
| C-5 Redirect-aware audit | **Done** | download service and gateway per-hop evaluation |
| C-6 Server allow-lists | **Done (origins, hosts)** | Origin allow-list, Host check, preflight, UI field. A trusted client-address list is not implemented |
| C-7 `finish_reason` length | **Partly done** | Non-streaming from measured counts; streaming has no measured count, so it still reports `stop` |
| C-8 Wire localization | **Partly done** | Infrastructure, picker, persistence, core strings. Screen-by-screen extraction and reviewed translations remain: good Starter tasks |
| C-9 RAG evaluation corpus | **Done** | `test/fixtures/rag_eval`, `rag_eval_test.dart`. Semantic and hybrid evaluation needs an embedding runtime and is Open |
| C-10 TalkBack and large text | **Partly done** | Large-text tests for four screens; a TalkBack walkthrough is Open and needs a device |
| C-11 Build-time releases | **Done** | `fetch-releases.mjs`, snapshot, tests |
| C-12 No canned replies | **Done** | sandbox gate, connect card, opt-in demo mode, Playwright |

### Suggested next batch (new, scoped)

1. **Extract strings for the chat input** to ARB keys (Starter; `chat_input.dart`
   is 1,700 lines, split by widget; acceptance: no English literals in the
   extracted widget, plus a locale test).
2. **Review the Spanish ARB file** with a native speaker and flip `reviewed`
   (Starter, needs a speaker).
3. **Contrast check of every primary button in light and dark themes** with a
   widget test using `meetsGuideline(textContrastGuideline)` (Starter).
4. **Replace-or-keep spike for `syncfusion_flutter_pdf`**: implement
   `PdfTextBackend` with a permissive engine and compare on the PDF fixtures
   (Advanced).
5. **llamadart adapter spike behind `InferenceService`** per
   `DEPENDENCY_LICENSING.md` (Advanced, needs an arm64 device).
6. **Streaming `finish_reason`**: expose a measured completion count from the
   pipeline's final event (Intermediate).
7. **Trusted client-address allow-list for the embedded server** (Intermediate).
8. **Dart dependency vulnerability check**: add a documented, non-blocking CI
   step using OSV-Scanner against `pubspec.lock` (Starter; verify the scanner's
   current Dart support first).

### Labels

`.github/labels.yml` defines the label set (area, difficulty, status,
compatibility). Sync it with a label-sync action or `gh label create` from the
file; it was not applied to the live repository in this pass.
