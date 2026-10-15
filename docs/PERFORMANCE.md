# Performance evidence

Measured 2026-10-15 (pass 2). Every number below was measured in this pass,
with the conditions stated. Nothing here is a phone benchmark.

## What was measured

| Measurement | Environment | Result |
| --- | --- | --- |
| Cold start, launch to first frame (`am start -W`, `TotalTime`) | Android 14 x86_64 **emulator** (WHPX, SwiftShader), release APK (debug-signed), app force-stopped before each run, 6 runs | 3378, 2077, 1980, 2087, 2643, 2671 ms. Median about 2.4 s, range 2.0 to 3.4 s |
| Process memory at the onboarding screen | same, after the last run | TOTAL PSS 117 MB, RSS 214 MB, Java heap 10 MB, native heap 30 MB |
| Release APK size, x86_64 only | `flutter build apk --release --target-platform android-x64` | 80.7 MB |
| Web: Next.js production build | Windows 11 host, Turbopack | compiles in about 2 to 11 s; one static route plus `/api/hf` |
| Web: Playwright suite (7 tests, desktop and mobile) | same host | 7 s total |
| Flutter unit and widget suite | same host | about 25 s for the full run |
| `flutter analyze` | same host | 15 to 40 s warm, 132 s cold |
| RAG keyword retrieval, 12 questions over 3 documents | host VM | hit@3 1.00, MRR 1.00 (synthetic corpus, regression guard only) |

Reproduce the emulator numbers with
`scripts/perf/android_cold_start.sh 6 emulator-5554`.

## What was not measured, and why

| Item | Reason |
| --- | --- |
| Model load time, first-token latency, tokens per second | The Cactus native library is shipped for `arm64-v8a` only (checked in the built APK). The x86_64 emulator cannot load it, and no arm64 device was available. The in-app Benchmark screen measures these on a real phone and can export a report (see below) |
| Peak RAM during inference, memory recovery after unload | Same |
| Battery and thermal behavior | No physical device |
| Scroll jank, frame timing, rebuild counts | No profiling session was run; `flutter run --profile` with DevTools on a device is the next step |
| Download throughput | Depends on the user's network and host; the download code reports live speed but no controlled test was run |

## Why the emulator figures are not phone figures

The emulator runs x86_64 code under hardware virtualization on a desktop CPU,
renders with a software GPU, and has different storage and memory behavior.
Phones are typically slower for cold start on mid-range hardware and have
tighter memory. Use the emulator numbers only to detect regressions between
builds on the same machine.

## Collecting real device numbers (contributors)

1. Install a release build on an arm64 phone and download a small model.
2. Run `scripts/perf/android_cold_start.sh 6` for launch time and idle memory.
3. In the app open **Settings > System, Benchmark & Updates > Benchmark**, run a
   test, and tap **Copy compatibility report**. The report contains hardware
   facts and that run's time to first token and tokens per second. It contains
   no prompts or outputs and is never uploaded.
4. File it with the **Device and model compatibility report** issue form.

Token counts in the report are labelled "runtime-measured" or "estimated from
text length". Estimated rates must not be quoted as measured speed.
