import { G } from './glyphs'

export type Tone = 'ok' | 'failed' | 'stopped'
export type ToastEvent = { tone: Tone; label: string }
export type ToastBatch = { at: number; events: ToastEvent[] }

/** Toasts closer than this to the batch start merge into one line. */
export const MERGE_MS = 2000

const GLYPH = { ok: G.ok, failed: G.fail, stopped: G.dim } as const
const WORD = { ok: 'done', failed: 'failed', stopped: 'stopped' } as const
const ORDER: Tone[] = ['failed', 'ok', 'stopped']

/** Adds an event to the open batch, or starts a new one past the window. */
export function pushToast(batch: ToastBatch | null, event: ToastEvent, now: number): ToastBatch {
  if (batch && now - batch.at <= MERGE_MS) return { at: batch.at, events: [...batch.events, event] }
  return { at: now, events: [event] }
}

/**
 * One line for a batch: `<glyph> <label> <word>` for a single event, else a
 * count per tone (`✕ 1 failed · ✓ 2 done`). The toast API has no color, so the
 * glyph carries the tone.
 */
export function toastText(events: ToastEvent[]): string {
  const [only] = events
  if (events.length === 1 && only) return `${GLYPH[only.tone]} ${only.label} ${WORD[only.tone]}`
  return ORDER.map(t => [t, events.filter(e => e.tone === t).length] as const)
    .filter(([, n]) => n > 0)
    .map(([t, n]) => `${GLYPH[t]} ${n} ${WORD[t]}`)
    .join(' · ')
}
