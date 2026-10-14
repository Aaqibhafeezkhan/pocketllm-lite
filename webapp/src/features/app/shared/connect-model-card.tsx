'use client';

/**
 * ConnectModelCard — what the user sees when no AI model is connected.
 * Replaces the old behaviour of silently answering with scripted text.
 */
import { PlugZap, ExternalLink, Wand2 } from 'lucide-react';
import { Button } from '@/components/ui/button';
import { router } from '@/lib/core/router';
import { useAppStore } from '@/lib/store/app-store';
import { cn } from '@/lib/utils';

export function ConnectModelCard({
  compact = false,
  className,
}: {
  compact?: boolean;
  className?: string;
}) {
  const patchSettings = useAppStore((s) => s.patchSettings);

  return (
    <section
      aria-labelledby="connect-model-title"
      data-testid="connect-model-card"
      className={cn(
        'mx-auto w-full max-w-xl rounded-2xl border border-border bg-card text-left shadow-sm',
        compact ? 'p-4' : 'p-6',
        className
      )}
    >
      <div className="flex items-start gap-3">
        <span className="flex h-10 w-10 shrink-0 items-center justify-center rounded-xl bg-brand-soft text-brand-strong dark:bg-brand/15">
          <PlugZap className="h-5 w-5" aria-hidden="true" />
        </span>
        <div className="min-w-0">
          <h2 id="connect-model-title" className="text-[15px] font-semibold">
            Connect an AI model to start chatting
          </h2>
          <p className="mt-1 text-[13px] leading-relaxed text-muted-foreground">
            PocketLLM Web does not ship a model. It talks to a runtime you
            control. Until one is connected it cannot answer, and it will never
            invent a reply.
          </p>
        </div>
      </div>

      {!compact && (
        <ol className="mt-4 space-y-2 text-[13px] leading-relaxed">
          <li className="flex gap-2">
            <span className="font-semibold text-brand-strong">1.</span>
            <span>
              Run <strong>Ollama</strong> on your computer and pull a model, for
              example{' '}
              <code className="rounded border border-border bg-muted/60 px-1 font-mono text-[12px]">
                ollama pull llama3.2
              </code>
              . Or have an OpenAI-compatible endpoint ready.
            </span>
          </li>
          <li className="flex gap-2">
            <span className="font-semibold text-brand-strong">2.</span>
            <span>Add it in Providers and press Test connection.</span>
          </li>
          <li className="flex gap-2">
            <span className="font-semibold text-brand-strong">3.</span>
            <span>
              Pick a model, then come back here. Requests go only to the
              address you enter.
            </span>
          </li>
        </ol>
      )}

      <div className="mt-4 flex flex-wrap items-center gap-2">
        <Button onClick={() => router.navigate('/app/providers')}>
          <PlugZap className="h-4 w-4" /> Connect a model
        </Button>
        <Button variant="outline" onClick={() => router.navigate('/app/wizard')}>
          <Wand2 className="h-4 w-4" /> Guided setup
        </Button>
        <a
          className="inline-flex items-center gap-1 px-1 text-[12.5px] text-muted-foreground underline-offset-2 hover:text-foreground hover:underline"
          href="https://ollama.com/download"
          target="_blank"
          rel="noopener noreferrer"
        >
          Get Ollama <ExternalLink className="h-3 w-3" aria-hidden="true" />
        </a>
      </div>

      <details className="mt-4 text-[12.5px] text-muted-foreground">
        <summary className="cursor-pointer select-none">
          Just exploring the interface? Demo mode
        </summary>
        <p className="mt-2 leading-relaxed">
          Demo mode answers with scripted text so you can see the screens. It
          is not a language model. Every demo reply is labelled
          &ldquo;Demo response&rdquo;.
        </p>
        <Button
          size="sm"
          variant="outline"
          className="mt-2"
          onClick={() =>
            // New chats must default to the demo runtime, otherwise they
            // would still target the unconfigured real one.
            patchSettings({
              chat: {
                sandboxEnabled: true,
                defaultRuntimeId: 'mock',
                defaultModelId: 'mock-echo',
              },
            })
          }
        >
          Turn on demo mode
        </Button>
      </details>
    </section>
  );
}
