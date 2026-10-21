import type { EngineInterface } from 'claude-code'
import { atom, read, update } from 'claude-code'

// The validator reads atoms only where they are declared in the same file, so
// each file declares the few it uses (same keys, same initials).
const running = atom({ plugin: 'look', key: 'running' } as const, {})
const now = atom({ plugin: 'look', key: 'now' } as const, 0)

const EXPIRE_MS = 30 * 60_000
const logged = new Set<string>()
// Only a handle: a reload drops it with the old timers, and `syncTick` on the
// next session.start starts one tick for whatever the atoms still hold.
let tickHandle: { cancel: () => void } | null = null

/** Logs the first error of each tag and swallows the rest. */
export function logOnce($: EngineInterface, tag: string, err: unknown): void {
  if (logged.has(tag)) return
  logged.add(tag)
  $.ui.log(`look: ${tag} failed: ${String(err)}`, { to: 'debug' })
}

/** Runs the 1 s tick only while something runs; safe to call at any time. */
export async function syncTick($: EngineInterface): Promise<void> {
  const busy = Object.keys(await read($, running)).length > 0
  if (busy && !tickHandle) {
    tickHandle = $.clock.every(1000, () => {
      void tick($)
    })
  } else if (!busy && tickHandle) {
    tickHandle.cancel()
    tickHandle = null
  }
}

async function tick($: EngineInterface): Promise<void> {
  try {
    const t = await $.clock.now()
    const items = await read($, running)
    const live = Object.entries(items).filter(([, i]) => i.kind !== 'shell' || t - i.startedAt < EXPIRE_MS)
    if (live.length < Object.keys(items).length) await update($, running, () => Object.fromEntries(live))
    await update($, now, () => t)
    await syncTick($)
  } catch (err) {
    logOnce($, 'tick', err)
  }
}
