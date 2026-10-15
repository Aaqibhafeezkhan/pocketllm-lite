/**
 * Smoke test for the Web Edition's Whisper path outside the browser.
 *
 * Loads the same model through the same library as `whisper.worker.ts`
 * (Transformers.js, `Xenova/whisper-tiny`) in Node, which proves that the
 * model repository is reachable, downloads, loads and runs inference. It does
 * not exercise the browser Worker or WASM paths, and it cannot judge
 * transcription quality: it feeds one second of silence and only checks that
 * the pipeline returns without error.
 *
 *   node scripts/check-whisper.mjs
 *
 * Downloads about 40 MB from huggingface.co on first run (cached afterwards).
 */
import { env, pipeline } from '@huggingface/transformers';

env.allowLocalModels = false;

const started = Date.now();
let lastLogged = -10;
const transcriber = await pipeline(
  'automatic-speech-recognition',
  'Xenova/whisper-tiny',
  {
    progress_callback: (p) => {
      if (p.status === 'progress' && Math.floor(p.progress / 20) !== lastLogged) {
        lastLogged = Math.floor(p.progress / 20);
        console.log(`download ${p.file}: ${Math.round(p.progress)}%`);
      }
    },
  }
);
const loadedMs = Date.now() - started;

const silence = new Float32Array(16000);
const runStarted = Date.now();
const output = await transcriber(silence, { chunk_length_s: 30 });
const text = (Array.isArray(output) ? output.map((o) => o.text).join(' ') : output.text).trim();

console.log(
  JSON.stringify({
    ok: true,
    modelLoadMs: loadedMs,
    inferenceMs: Date.now() - runStarted,
    returnedText: text.length > 0 ? 'non-empty' : 'empty',
  })
);
