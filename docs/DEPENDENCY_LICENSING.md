# Dependency licensing, security and backend strategy

Assessed 2026-10-15 (pass 2). Sources are the package pages and vendor pages
named below, fetched on that date. This is an engineering assessment, not legal
advice; the maintainer should confirm anything marked "needs maintainer".

PocketLLM Lite's own source is MIT. A dependency's license is separate: the MIT
license of this repository does not relicense a dependency, and users who fork,
rebuild or redistribute the app are bound by each dependency's own terms.

## 1. `syncfusion_flutter_pdf` (PDF text extraction)

| Question | Finding | Source |
| --- | --- | --- |
| License | A Syncfusion license; pub.dev lists it as "unknown". Use requires a Syncfusion Community License or a commercial license | [pub.dev license tab](https://pub.dev/packages/syncfusion_flutter_pdf/license) |
| Community eligibility | Gross revenue under US$1M; 5 or fewer developers; 10 or fewer employees; never more than US$3M outside capital | [Syncfusion Community License](https://www.syncfusion.com/products/communitylicense) |
| Open-source projects | May use it, but must contact Syncfusion to register first | same |
| Redistribution | Not addressed on the pages read | same |
| Used where | Only `lib/services/document_ingestion_service.dart` (`SyncfusionPdfTextBackend`) | source |
| License key in code | None registered (`registerLicense` is not called) | grep |

Assessment:

- The project is likely eligible for the Community License, but eligibility
  depends on the maintainer's organization and funding, and registration is a
  precondition for open-source use. **Needs maintainer:** register with
  Syncfusion and record the outcome.
- Because the license is not OSI-approved and redistribution is unaddressed, the
  repository must not describe the whole app as "fully open source" without this
  caveat. It also makes inclusion in FOSS-only catalogs (for example F-Droid)
  unlikely while the dependency remains.
- PDF support is functional and tested (new `test/services/pdf_ingestion_test.dart`
  builds a three-page PDF and verifies per-page text and citations), so it was
  not removed.

What changed in this pass: the PDF engine now sits behind a `PdfTextBackend`
interface. Replacing it means implementing one method (`extractPages`) and
passing the new backend to `DocumentIngestionService`. Chunking, citations and
retrieval are untouched, and a fake backend is covered by tests.

### Replacement candidates (not adopted)

| Candidate | License | Evidence read | Why it is not adopted yet |
| --- | --- | --- | --- |
| [`pdfrx`](https://pub.dev/packages/pdfrx) | MIT (PDFium binaries are bundled; PDFium is separately licensed) | Text extraction API exists (`PdfPage.loadText`/`PdfPageText`, per changelog). Latest 2.6.x requires Dart 3.13 and Flutter 3.47; this project is on Flutter 3.41.9 / Dart 3.11.5 | Needs an older compatible version or a Flutter upgrade, and a measured comparison on real PDFs (pagination, Unicode, memory) on a device. Not done here, so no quality claim is made |

Decision rule for a swap: it must match or beat the current backend on a
fixed PDF set (page text order, non-Latin text, large file memory) in a
committed test, and its bundled-binary licenses must be recorded here.

## 2. `cactus` (on-device inference)

| Question | Finding |
| --- | --- |
| Package | `cactus` 1.3.0 on pub.dev, verified publisher cactuscompute.com, Android API 24+, license listed as "unknown" ([page](https://pub.dev/packages/cactus)) |
| Maintenance | The Flutter repository was archived upstream in July 2026 (see `KNOWN_LIMITATIONS.md`); the last release is about nine months old |
| Telemetry | Enabled by default upstream; PocketLLM disables it and blocks the unmanaged download paths |
| Isolation | Already behind `InferenceService` adapters, so a second backend can be added without rewriting the chat pipeline |

Strategy (no premature rewrite):

1. Keep Cactus as the shipped local backend. Do not extend its integration.
2. Run a time-boxed spike for **`llamadart`**, the most active llama.cpp
   binding found in a 2026-10-15 search ([docs](https://pub.dev/documentation/llamadart/latest/)):
   prebuilt native runtimes resolved at build, streaming chat, embeddings,
   tool-call parsing. Package license and Android ABI coverage were **not
   verified** and are spike entry criteria.
3. Spike exit criteria, all measured on a physical device with the same GGUF:
   load success, tokens per second, first-token latency, peak RAM, cancellation
   latency, and that no telemetry or undeclared network request occurs under
   Strict Offline.
4. Ship a second adapter behind a setting only if it wins on those measures.
   Existing user models must keep loading through Cactus until a migration is
   proven.

Other candidates seen but not preferred: `llama_cpp_dart` (needs a compiled
llama.cpp per target) and `fllama` (version 0.0.1; pub.dev and GitHub licenses
disagree, so it must not be used without clarification).

## 3. Web Edition npm advisories (re-assessed individually)

`npm audit --omit=dev`: 9 advisories before, **0 after**.

| Package (severity) | Reachability | Action |
| --- | --- | --- |
| `next` 16.3.5 (critical, several) | Framework in production | Updated to 16.4.1 in pass 1 |
| `js-yaml` via `@mdxeditor/editor` (high/moderate) | No importer anywhere in `src/` | Dependency removed |
| `prismjs`, `refractor` via `react-syntax-highlighter` (moderate) | No importer in `src/` | Dependency removed |
| `deepmerge-ts` via `prisma` / `@prisma/config` (high) | Only `src/lib/db.ts`, which nothing imported; build-time CLI | `prisma`, `@prisma/client`, `src/lib/db.ts`, `prisma/` removed |
| `sharp` (high: libvips, libheif, librsvg) | Next image optimizer; the app uses no `next/image` and no remote image patterns | Upgraded 0.34 to 0.35.5 |
| `source-map-js` (high) | Build-time | Cleared by pass-1 `npm audit fix` |

Remaining, dev-only (`npm audit`, not `--omit=dev`): `braces` via
`eslint-config-next > @next/eslint-plugin-next > fast-glob > micromatch`
(stack-exhaustion DoS on deeply nested glob patterns). It is not shipped, the
lint config supplies no untrusted patterns, and npm's only offered "fix" is a
downgrade to `eslint-config-next@14`, so it is accepted and tracked.

`webapp/bun.lock` is stale relative to `package-lock.json`. CI uses npm. Either
regenerate it with Bun or delete it; this pass did not touch it because Bun
was not available to verify the result.

## 4. Flutter side

`flutter pub get` reports one discontinued package and 141 newer, constraint-
blocked versions. The discontinued package was not identified in this pass
(`flutter pub outdated` output not captured); that is a follow-up. There is no
Flutter equivalent of `npm audit` in the toolchain, so Dart dependency
vulnerabilities are not machine-checked here.
