'use client';

/**
 * useModelConnection — reports whether a real model runtime is configured.
 *
 * "connected" means a provider record with a selected model exists. It does
 * not probe the network, so it is instant and works offline; the Providers
 * view owns live connection tests. While the first lookup is in flight the
 * status is "checking" so the UI never flashes a false "disconnected".
 */
import { useEffect, useState } from 'react';
import { bus } from '@/lib/core/events/event-bus';
import { inferenceRouter } from '@/lib/services/inference/inference-router';
import { useAppStore } from '@/lib/store/app-store';

export type ModelConnectionStatus = 'checking' | 'connected' | 'disconnected';

export interface ModelConnection {
  status: ModelConnectionStatus;
  /** Demo (scripted) runtime explicitly enabled by the user. */
  sandboxEnabled: boolean;
  /** No real model AND no demo opt-in: generation must not be offered. */
  blocked: boolean;
}

export function useModelConnection(): ModelConnection {
  const sandboxEnabled = useAppStore((s) => s.settings.chat.sandboxEnabled);
  const [status, setStatus] = useState<ModelConnectionStatus>('checking');

  useEffect(() => {
    let alive = true;
    const check = () => {
      void inferenceRouter
        .hasConnectedProvider()
        .then((ok) => alive && setStatus(ok ? 'connected' : 'disconnected'))
        .catch(() => alive && setStatus('disconnected'));
    };
    check();
    const un = bus.on('providers:changed', check);
    return () => {
      alive = false;
      un();
    };
  }, []);

  return {
    status,
    sandboxEnabled,
    blocked: status === 'disconnected' && !sandboxEnabled,
  };
}
