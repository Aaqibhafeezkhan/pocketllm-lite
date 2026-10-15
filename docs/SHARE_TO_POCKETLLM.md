# Share to PocketLLM

Android users can send text, links and a few document types from any app to
PocketLLM using the standard share sheet. Nothing is processed until the user
chooses an action, and nothing is kept unless they choose to save it.

## What is accepted

| Shared item | Handling |
| --- | --- |
| Plain text (`text/plain`, `ACTION_SEND`) | Previewed, up to 200 KB. Links inside it are listed. |
| A link on its own | Shown, with an explanation that PocketLLM does not fetch pages. |
| PDF, `.txt`, `.md`, `.csv` | Copied to a private inbox, up to 25 MB each and 5 per share. |
| Several documents (`ACTION_SEND_MULTIPLE`) | Same limits; extras beyond five are reported, not used. |
| Anything else (images, archives, executables, Office files) | Refused with a visible reason. |

## Actions

* **Summarize**: starts a new chat with the content and a summarise instruction.
* **Ask a question**: starts a new chat that answers only from the shared content.
* **Save to knowledge base**: indexes documents (or shared text) through the same
  ingestion path as the Document Manager. Links are not saved.

Summarize and Ask go to the model the user has already configured (on-device
Cactus bundle, Ollama, or a remote provider). If no model is ready the user is
told so and sent to model setup; nothing is invented.

## Safety rules

Enforced in `ShareIntentHandler.kt` (platform) and `SharedContentPolicy` (Dart):

* Only `content://` URIs are read. `file://` is refused because it would let
  another app point PocketLLM at its own private files.
* URIs that belong to PocketLLM's own FileProvider are refused.
* Size is counted while copying; the sender's declared size is not trusted.
* Files are copied to `cache/shared_inbox/<uuid>/<sanitised-name>` immediately,
  because the sender's temporary read grant only lasts while the activity is
  alive. Names are stripped of path separators and special characters.
* Dart accepts only paths inside the inbox, so a malformed payload cannot make
  the app read or delete anything else.
* Copies that are refused are deleted at once; accepted copies are deleted when
  the user leaves the share screen or the action starts. Folders older than 24
  hours are purged on the next launch (crash or force-stop).
* No network request is made on receipt. A shared link is never fetched
  automatically.
* Shared content is treated as data. It is placed in the user message and is
  never executed or interpreted as instructions to the app.

## Where the code lives

| Piece | File |
| --- | --- |
| Android intent parsing, copy, purge | `android/app/src/main/kotlin/com/pocketllm/pocketllm_lite/ShareIntentHandler.kt` |
| Channel wiring and `onNewIntent` | `MainActivity.kt` |
| Intent filters | `AndroidManifest.xml` |
| Validation policy | `lib/services/shared_content.dart` |
| Platform bridge | `lib/services/share_intake_service.dart` |
| State and cold/warm start routing | `lib/features/sharing/providers/share_provider.dart` |
| Screen | `lib/features/sharing/presentation/share_receiver_screen.dart` |

## Tests

* `test/services/shared_content_test.dart`: policy (types, sizes, traversal, links).
* `test/features/sharing/share_receiver_screen_test.dart`: screen states and
  inbox cleanup behaviour.
* Device check: see the Phase 3 report for the `adb shell am start -a
  android.intent.action.SEND` runs and what they showed.

## Known limits

* Image and Word/Excel/PowerPoint sharing is not supported yet. Images would
  need an explicit decision about OCR vs. vision-model input.
* Scanned PDFs without a text layer are rejected by the existing ingestion
  step with its usual message.
* Very long documents are truncated to the first 24,000 characters for
  Summarize/Ask. Use Save to knowledge base for retrieval over larger files.

## Device evidence (Android 14 x86_64 emulator, debug build)

Run on 15 Oct 2026. This is an emulator, so it verifies the intent, copy,
validation, cleanup and UI paths. It does not verify model output.

| Case | Result |
| --- | --- |
| `ACTION_SEND` text + subject, cold start (via system chooser) | Share screen shown with subject, text and extracted link (`docs/screenshots/android/share-text.png`). |
| Same, app already running (`onNewIntent`) | Replaced the previous preview without restarting. |
| Real file shared from the system Files app (granted `content://`) | Copied to `cache/shared_inbox/<uuid>/`, preview shows name and size (`share-file.png`). |
| Leaving the share screen | `cache/shared_inbox` was empty afterwards. |
| `content://` URI with no grant (`adb` cannot grant media access) | Refused as "The sending app denied access to the file"; nothing left in the inbox (`share-denied.png`). |
| Nonexistent `content://` item | Refused with a plain message; no raw exception text shown. |

Not exercised on device: `ACTION_SEND_MULTIPLE`, PDF extraction, the 25 MB cap,
and the Summarize/Ask path with a real model (no arm64 inference available
here). The size cap and multiple-file limits are covered by unit tests only.
