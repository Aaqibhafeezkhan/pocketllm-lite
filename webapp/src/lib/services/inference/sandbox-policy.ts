/**
 * Sandbox policy — the single place that decides whether the deterministic
 * "Offline Sandbox" demo runtime may answer.
 *
 * The sandbox produces scripted text, not model output. It must never be the
 * silent fallback for an unconfigured app: it only runs after the user opts in
 * on purpose, and every message it produces is labelled in the thread.
 * Pure module (no IndexedDB / DOM) so it can be unit tested in isolation.
 */
import type { RuntimeId } from '@/lib/types/domain';

export const NO_MODEL_CONNECTED_MESSAGE =
  'No AI model is connected. Connect Ollama or an OpenAI-compatible endpoint in Providers to get real answers.';

export class NoModelConnectedError extends Error {
  readonly code = 'no_model_connected' as const;
  constructor(message: string = NO_MODEL_CONNECTED_MESSAGE) {
    super(message);
    this.name = 'NoModelConnectedError';
  }
}

/** True when this runtime id is the scripted demo runtime. */
export function isSandboxRuntime(runtimeId: RuntimeId | string | undefined): boolean {
  return runtimeId === 'mock';
}

/**
 * Throws NoModelConnectedError when the sandbox is requested without the
 * explicit opt-in. Every real runtime passes through unchanged.
 */
export function assertRuntimeAllowed(
  runtimeId: RuntimeId,
  sandboxEnabled: boolean
): void {
  if (isSandboxRuntime(runtimeId) && !sandboxEnabled) {
    throw new NoModelConnectedError();
  }
}

/** Provider records that can actually answer (a model is selected). */
export function hasUsableProvider(
  providers: ReadonlyArray<{ type: string; modelId?: string | null }>
): boolean {
  return providers.some(
    (p) => (p.type === 'ollama' || p.type === 'openai-compatible') && !!p.modelId
  );
}
