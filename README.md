<div align="center">

<img src="assets/logo.png" width="96" alt="PocketLLM Lite logo" />

# PocketLLM Lite

**A local-first AI chat app for Android. Your models, your documents, your device.**

[![Flutter](https://img.shields.io/badge/Flutter-3.41-02569B?logo=flutter)](https://flutter.dev)
[![Version](https://img.shields.io/badge/version-1.0.40-6750A4)](CHANGELOG.md)
[![License: MIT](https://img.shields.io/badge/License-MIT-2E7D32.svg)](LICENSE)

[Download APK (v1.0.40)](https://github.com/PocketLLM/pocketllm-lite/releases/tag/v1.0.40) ·
[Website](https://pocketllm-lite.vercel.app/) ·
[Quick start](#try-it-in-five-minutes) ·
[Known limitations](docs/KNOWN_LIMITATIONS.md) ·
[Contribute](CONTRIBUTING.md)

</div>

---

## Why PocketLLM Lite

- **It actually runs on your phone.** Cactus-format model bundles (the in-app
  catalog downloads these) run on-device through the
  [Cactus](https://github.com/cactus-compute/cactus) runtime. No account and no
  hosted inference. GGUF files are not loadable on-device; use them through
  Ollama or another OpenAI-compatible server.
- **You decide when the network is used.** Every app-managed connection goes
  through one policy gateway with a visible audit log. *Strict Offline Mode*
  blocks all non-loopback traffic from the app.
- **Bring your own runtime when you want to.** Connect Ollama on your own
  machine or any OpenAI-compatible endpoint. PocketLLM tells you which requests
  leave the device.
- **Your documents stay yours.** Import PDF, TXT, Markdown, or CSV and chat with
  them using keyword, semantic, or hybrid retrieval with source references.
- **No ads, no analytics, no tracking SDKs.** A regression test in
  [`test/regressions`](test/regressions) fails the build if they appear.

## What it looks like

Real screenshots from the development build on an Android 14 emulator. These
show the v1.0.40 build.

| First-launch model step | Chat with no model ready | Chat menu |
| --- | --- | --- |
| <img src="docs/screenshots/android/android14-emulator-onboarding-first-model.png" width="220" alt="Onboarding step listing ways to get a model: find one for this phone, use your own server, import a GGUF, decide later" /> | <img src="docs/screenshots/android/android14-emulator-chat-no-model.png" width="220" alt="Chat screen with a Set up a model chip, history, new chat and menu actions, and Get a model, Connect a server and Setup guide buttons" /> | <img src="docs/screenshots/android/android14-emulator-chat-overflow-menu.png" width="220" alt="Chat overflow menu with chat settings, media, and app settings" /> |

## What works in v1.0.40

| Area | What you get |
| --- | --- |
| Chat | Streaming local chat, persistent history, branches, tags, personas, prompts, skills, per-chat system prompts |
| Models | On-device Cactus catalog, Hugging Face GGUF search for server use (with a copyable `ollama run` command), gated-repo token support, resumable verified downloads, local folder import, device-aware recommendations |
| Documents | PDF/TXT/MD/CSV ingestion, keyword / semantic / hybrid retrieval, source-aware answers |
| Vision & OCR | Android on-device OCR (ML Kit Latin). Image input only when the selected model confirms vision support |
| Voice | On-device Whisper transcription via a guided, checksum-verified model install; text-to-speech |
| Tools | Validated JSON tool calls: safe math, system info, clipboard, notes, reminders, email draft, browser, policy-gated web search. State-changing tools ask first |
| Memory | Local memories linked to their source message, rolling summaries |
| Privacy | Strict Offline Mode, network audit log, secure-storage keys, password-derived AES-256-GCM `.pllm` backups with rollback on failed restore |
| Developer | Authenticated OpenAI-compatible server (`/v1/models`, `/v1/chat/completions` with SSE, `/v1/embeddings`), loopback by default |
| Lab | Prompt Lab, side-by-side model comparison, on-device benchmarks |
| UI | Material 3 light/dark, dynamic color. English only today: translation files for six languages exist but hold 15 strings and are not wired into the UI yet |

Anything not listed here is not claimed. See
[`docs/KNOWN_LIMITATIONS.md`](docs/KNOWN_LIMITATIONS.md) for the honest gaps.

## Try it in five minutes

1. **Install.** Download the APK for your device from the
   [v1.0.40 release](https://github.com/PocketLLM/pocketllm-lite/releases/tag/v1.0.40)
   (`arm64-v8a` for most phones from 2017 onward; compare the file against
   `SHA256SUMS.txt`). **Only the `arm64-v8a` build contains the on-device model
   runtime.** The `armeabi-v7a` and `x86_64` builds can still use an Ollama or
   OpenAI-compatible server, OCR and documents, but cannot run on-device models. Android 7.0 (API 24) or newer. Release APKs are
   debug-signed engineering builds (same signer as v1.0.13 to v1.0.38), see
   [Known limitations](docs/KNOWN_LIMITATIONS.md).
2. **Finish onboarding.** It explains the model options and asks you to choose
   your network permissions (update checks and online model browsing are
   optional; Strict Offline Mode is one switch). Then pick a path:
   - *On-device*: open the model selector, choose a small verified model, and
     let it download over Wi-Fi (a 1 B parameter model at Q4 is roughly 0.7 to
     1 GB).
   - *Your own server*: add an Ollama or OpenAI-compatible URL in settings.
3. **Chat.** The selected model, not a canned reply, produces every response. If
   a prerequisite is missing, the app says so instead of faking success.
4. **Optional:** import a document, turn on Strict Offline Mode, or try voice.

### Hardware guidance

Memory is the limit. As a rule of thumb, the model file plus its context cache
must fit in free RAM with headroom for Android itself. PocketLLM recommends
conservatively and shows `unknown` when the device does not expose a
measurement. Compatibility depends on the exact file, quantization, device, and
thermal state, and PocketLLM loads only Cactus-format bundles, never GGUF. Reports with device and
model details are very welcome (see [Contributing](#contributing)).

## Privacy model in one paragraph

Chats, documents, indexes, and memories live in the app sandbox. Local inference
never sends content anywhere. Network access happens only for explicit,
displayed purposes (model discovery/download, update checks you enable, web
search you enable, remote runtimes you configure). Strict Offline Mode blocks
all of it except loopback. It is an application-level boundary, not a device
firewall; handing content to another app (for example an email composer) is
outside its reach. Details: [`SECURITY.md`](SECURITY.md) and
[`assets/network_policy.json`](assets/network_policy.json).

## Build from source

```bash
git clone https://github.com/PocketLLM/pocketllm-lite.git
cd pocketllm-lite
flutter pub get
flutter analyze
flutter test
flutter run                      # needs an Android device or emulator
flutter build apk --split-per-abi --release
```

Flutter stable (3.41+) and Android SDK are required. More in
[`CONTRIBUTING.md`](CONTRIBUTING.md).

## Repository layout

```text
lib/
├─ core/        theme, shared Material 3 widgets, routing
├─ features/    chat, model_browser, rag, settings, onboarding, media, ...
├─ services/    inference, network gateway/policy, downloads, RAG, tools, backup
└─ models/      Hive models and manifests
webapp/         Web Edition (Next.js) and the marketing website
docs/           audits, verification reports, known limitations
```

## Web Edition

[`webapp/`](webapp/) contains a Next.js browser edition and the marketing site.
It runs against Ollama or OpenAI-compatible endpoints you control and keeps its
data in IndexedDB. It does not include the Android on-device runtime.

## Contributing

PocketLLM Lite is MIT licensed. Bug reports, device and model compatibility
evidence, translations, accessibility fixes, documentation, tests, and focused
code are welcome. Start with [`CONTRIBUTING.md`](CONTRIBUTING.md), follow the
[code of conduct](CODE_OF_CONDUCT.md), and browse
[`good first issue`](https://github.com/PocketLLM/pocketllm-lite/labels/good%20first%20issue)
labels. Report vulnerabilities privately via [`SECURITY.md`](SECURITY.md).

## Further reading

[Changelog](CHANGELOG.md) ·
[Release notes](RELEASE_NOTES.md) ·
[v1.0.38 verification](docs/V1_0_38_VERIFICATION.md) ·
[Product audit](docs/V1_0_36_PRODUCT_AUDIT.md)
