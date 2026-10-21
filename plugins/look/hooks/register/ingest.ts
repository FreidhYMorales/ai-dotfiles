import type { EngineInterface } from 'claude-code'
import { atom, read, update } from 'claude-code'

import { normalizeCommand, shellLabel } from '../lib/label'
import { mapStatus } from '../lib/status'
import { pushToast, toastText } from '../lib/toast'
import type { Tone, ToastBatch } from '../lib/toast'
import { logOnce, syncTick } from './timers'

// The validator reads atoms only where they are declared in the same file, so
// each file declares the few it uses (same keys, same initials).
const running = atom({ plugin: 'look', key: 'running' } as const, {})
const shellFails = atom({ plugin: 'look', key: 'shellFails' } as const, {})
const now = atom({ plugin: 'look', key: 'now' } as const, 0)

type Task = { id?: string; status?: string }

const LABEL_MAX = 40
const queued = new Set<string>()
let batch: ToastBatch | null = null

function toast($: EngineInterface, tone: Tone, label: string, at: number): void {
  batch = pushToast(batch, { tone, label }, at)
  $.ui.toast(toastText(batch.events))
}

const without = <T,>(rec: Record<string, T>, key: string): Record<string, T> =>
  Object.fromEntries(Object.entries(rec).filter(([k]) => k !== key))

/** A background Bash call started: remember it by its task id. */
export async function onBash($: EngineInterface, e: any, out: any): Promise<void> {
  try {
    const id: unknown = out?.result?.backgroundTaskId
    if (e.tool !== 'Bash' || !e.run_in_background || typeof id !== 'string') return
    const at = await $.clock.now()
    const key = normalizeCommand(e.command)
    const item = { id, toolUseId: e.tool_use_id, kind: 'shell', label: shellLabel(e.description, key, LABEL_MAX), key, startedAt: at } as const
    await update($, running, r => ({ ...r, [id]: item }))
    await update($, now, () => at)
    await syncTick($)
  } catch (err) {
    logOnce($, 'bash', err)
  }
}

/**
 * Called from the render of a task notification: it only reads. A known id is
 * queued once and finished after a zero-delay dispatch, because state writes
 * are refused while drawing. Unknown, finished and repeated ids do nothing.
 */
export async function onNotification($: EngineInterface, task: Task | undefined): Promise<void> {
  try {
    const id = task?.id
    if (!id || queued.has(id) || !(id in (await read($, running)))) return
    queued.add(id)
    $.clock.after(0, () => {
      void finish($, id, mapStatus(task.status))
    })
  } catch (err) {
    logOnce($, 'notification', err)
  }
}

async function finish($: EngineInterface, id: string, tone: Tone): Promise<void> {
  try {
    const item = (await read($, running))[id]
    if (!item) return
    const at = await $.clock.now()
    await update($, running, r => without(r, id))
    if (item.key && tone === 'ok') await update($, shellFails, f => without(f, item.key!))
    if (item.key && tone === 'failed') await update($, shellFails, f => ({ ...f, [item.key!]: { key: item.key!, label: item.label, at } }))
    toast($, tone, item.label, at)
    await syncTick($)
  } catch (err) {
    logOnce($, 'finish', err)
  } finally {
    queued.delete(id)
  }
}
