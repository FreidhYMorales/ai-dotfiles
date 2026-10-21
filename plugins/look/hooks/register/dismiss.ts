import type { EngineInterface } from 'claude-code'
import { atom, read, update } from 'claude-code'

import { dismissKey, PREFIX, splitDismissals } from '../lib/dismiss'
import { logOnce } from './timers'

// The validator reads atoms only where they are declared in the same file, so
// each file declares the few it uses (same keys, same initials).
const running = atom({ plugin: 'look', key: 'running' } as const, {})
const shellFails = atom({ plugin: 'look', key: 'shellFails' } as const, {})
const alerts = atom({ plugin: 'look', key: 'alerts' } as const, [])
const dismissed = atom({ plugin: 'look', key: 'dismissed' } as const, [])

const TICK_MS = 5000
// Only a handle: a reload drops it with the old timers and the next
// session.start starts one again.
let tickHandle: { cancel: () => void } | null = null

/** Writes one store key per source, then shows them as dismissed here at once. */
export async function dismiss($: EngineInterface, sources: string[]): Promise<void> {
  try {
    const at = await $.clock.now()
    for (const s of sources) await $.store.set(dismissKey(s), { at })
    await update($, dismissed, d => [...new Set([...d, ...sources])])
  } catch (err) {
    logOnce($, 'dismiss', err)
  }
}

/** `/band clear`: dismiss every alert, drop running items and shell failures. */
export async function clearBand($: EngineInterface): Promise<void> {
  try {
    await dismiss($, (await read($, alerts)).map(a => a.source))
    await update($, running, () => ({}))
    await update($, shellFails, () => ({}))
  } catch (err) {
    logOnce($, 'clear', err)
  }
}

/** Re-reads the shared dismissals, prunes the stale ones and updates the atom. */
export async function syncDismissed($: EngineInterface): Promise<void> {
  try {
    const now = await $.clock.now()
    const keys = (await $.store.keys()).filter(k => k.startsWith(PREFIX))
    const entries = await Promise.all(keys.map(async key => ({ key, at: ((await $.store.get(key)) as { at?: number } | undefined)?.at })))
    const { live, stale } = splitDismissals(entries, now)
    for (const key of stale) await $.store.delete(key)
    const same = (a: string[], b: string[]): boolean => a.length === b.length && a.every(x => b.includes(x))
    await update($, dismissed, d => (same(d, live) ? d : live))
  } catch (err) {
    logOnce($, 'dismissals', err)
  }
}

/** Starts the 5 s re-read once; safe to call at any time. */
export async function startDismissTick($: EngineInterface): Promise<void> {
  await syncDismissed($)
  if (tickHandle) return
  tickHandle = $.clock.every(TICK_MS, () => {
    void syncDismissed($)
  })
}
