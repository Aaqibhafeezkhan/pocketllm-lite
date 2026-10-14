import { describe, expect, it } from 'vitest';
import {
  NO_MODEL_CONNECTED_MESSAGE,
  NoModelConnectedError,
  assertRuntimeAllowed,
  hasUsableProvider,
  isSandboxRuntime,
} from './sandbox-policy';

describe('sandbox policy', () => {
  it('refuses the scripted runtime unless the user opted in', () => {
    expect(() => assertRuntimeAllowed('mock', false)).toThrow(NoModelConnectedError);
    try {
      assertRuntimeAllowed('mock', false);
    } catch (error) {
      expect((error as NoModelConnectedError).code).toBe('no_model_connected');
      expect((error as Error).message).toBe(NO_MODEL_CONNECTED_MESSAGE);
    }
  });

  it('allows the scripted runtime after an explicit opt-in', () => {
    expect(() => assertRuntimeAllowed('mock', true)).not.toThrow();
  });

  it('never blocks real runtimes', () => {
    expect(() => assertRuntimeAllowed('ollama', false)).not.toThrow();
    expect(() => assertRuntimeAllowed('openai', false)).not.toThrow();
  });

  it('only the mock runtime id counts as the sandbox', () => {
    expect(isSandboxRuntime('mock')).toBe(true);
    expect(isSandboxRuntime('ollama')).toBe(false);
    expect(isSandboxRuntime(undefined)).toBe(false);
  });

  it('a provider without a selected model is not usable', () => {
    expect(hasUsableProvider([])).toBe(false);
    expect(hasUsableProvider([{ type: 'ollama', modelId: '' }])).toBe(false);
    expect(hasUsableProvider([{ type: 'ollama', modelId: null }])).toBe(false);
    expect(hasUsableProvider([{ type: 'unknown', modelId: 'x' }])).toBe(false);
    expect(hasUsableProvider([{ type: 'ollama', modelId: 'llama3.2' }])).toBe(true);
    expect(
      hasUsableProvider([{ type: 'openai-compatible', modelId: 'gpt' }])
    ).toBe(true);
  });
});
