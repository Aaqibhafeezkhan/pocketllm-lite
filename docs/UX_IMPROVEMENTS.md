# PocketLLM Lite UX Improvements

Written 2026-10-15. Scope and honesty note: this pass had no device or emulator,
so there is **no new before/after screenshot set and no frame-time or startup
measurement**. The Android observations below come from the v1.0.36 screenshots
already in `artifacts/` plus source reading; the current build may differ. The
web observations come from a live browser check of the production build.

## 1. Changes made

| Surface | Before | After | Why |
| --- | --- | --- | --- |
| Chat empty-state suggestions | Included "Create an image of a snowboarder in the Alps"; the app has no image generation | Three text-model tasks (explain, draft, summarize) | A suggestion the product cannot fulfil is a broken promise on the first screen |
| Chat "Not Connected" state | "Please ensure Ollama is running and connected" | "No model is ready. Download an on-device model, or connect an Ollama or OpenAI-compatible server." | On-device models are the primary path; the old copy implied Ollama was required |
| Markdown blocked-image placeholder | `Colors.grey` literals | `surfaceContainerHighest`, `outlineVariant`, `onSurfaceVariant` | Theme tokens, correct in dark mode (project rule 1.1) |
| Starred-message icon | `Colors.amber.shade600` | `colorScheme.tertiary` | Same |
| Web typography | Google Fonts `<link>` at runtime | Self-hosted via `next/font` | No third-party request, no render-blocking CSS from another origin |
| Web social previews | Image URLs resolved to localhost | Absolute URLs, Twitter card | Links shared on social/chat apps now preview |

Files: `lib/features/chat/presentation/widgets/chat_body.dart`,
`lib/core/utils/markdown_handlers.dart`,
`lib/features/chat/presentation/widgets/chat_bubble.dart`,
`webapp/src/app/layout.tsx`, `webapp/src/app/globals.css`.

## 2. Observations still open

| # | Severity | Observation | Evidence | Suggested change |
| --- | --- | --- | --- | --- |
| U1 | High | Onboarding explains options in prose across three pages but never lets the user start a model download; the first chat still lands on an empty "No models" state | `onboarding_screen.dart`, v1.0.36 screenshots | Add a final onboarding step that shows device-aware recommendations (the recommendation engine exists) with one "Download" action and an explicit "Use my own server" choice |
| U2 | High | The top app bar has five icon-only actions at 360 dp plus a truncated model name ("No Models ...") | `v1.0.36-final-360dp-chat-light.png` | Move gallery/history into the leading drawer or overflow menu; give the model chip priority width; keep touch targets at 48 dp |
| U3 | Medium | Composer's disclaimer ("This is A.I. and not a real person. Treat everything it says as opinion") wraps to two small lines and a chevron with unclear meaning | same screenshot | One line, or fold into an info affordance; label the chevron |
| U4 | Medium | The empty-state suggestion chips cannot adapt to capability (vision, tools, RAG on) | `chat_body.dart` | Derive suggestions from enabled capabilities; hide any that need a missing prerequisite |
| U5 | Medium | Web Edition canned "Offline Sandbox" is the default answerer | PROJECT_AUDIT O14 | Replace with a connect-a-model prompt |
| U6 | Medium | Only one widget test checks large-text layout | `test/widgets/` | One 360 x 640, 1.3 text-scale pump per primary screen |
| U7 | Low | Store/README art shows the old Ollama-only UI and an absolute offline claim | PROJECT_AUDIT O11 | Re-shoot from the current build |
| U8 | Low | Customization screen has the most hardcoded colors (26) | grep | Confirm they are user-selectable swatches; otherwise map to theme |

## 3. Design principles to hold

- Honesty first: no control, suggestion or message may imply a capability that
  is not available. Disabled with a reason beats hidden.
- One primary action per empty state; the primary action should move the user
  toward a working chat (download a model, connect a server).
- Motion is restrained and respects reduced-motion settings; streaming should
  not animate layout per token.
- Every error says what happened, what was not done, and what to do next.

## 4. Verification of the web changes

Built with `next build`, served with `next start`, loaded in the built-in
browser at 375 x 812: no horizontal page scroll (scroll width equals viewport),
no console messages, and the resource list contains only same-origin requests
plus one `api.github.com` call (PROJECT_AUDIT O4). Text color on the hero
measured `rgb(21, 19, 26)` after the reveal transition finished. Lighthouse and
axe were not run.
