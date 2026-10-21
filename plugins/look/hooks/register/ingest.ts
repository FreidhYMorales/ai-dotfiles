import type { EngineInterface } from 'claude-code'
import { atom, read, update } from 'claude-code'

import { normalizeCommand, shellLabel } from '../lib/label'
import { truncate } from '../lib/layout'
import { mapStatus } from '../lib/status'
import { pushToast, toastText } from '../lib/toast'
import type { Tone, ToastBatch } from '../lib/toast'
import { logOnce, syncTick } from './timers'

// The validator reads atoms only where they are declared in the same file, so
// each file declares the few it uses (same keys, same initials).
const running = atom({ plugin: 'look', key: 'running' } as const, {})
const shellFails = atom({ plugin: 'look', key: 'shellFails' } as const, {})
const alerts = atom({ plugin: 'look', key: 'alerts' } as const, [])
const now = atom({ plugin: 'look', key: 'now' } as const, 0)

type Task = { id?: string; status?: string; toolUseId?: string }

const LABEL_MAX = 40
const queued = new Set<string>()
let batch: ToastBatch | null = null
const AGENT_POLL_MS = 60_000
let pollHandle: { cancel: () => void } | null = null

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
    const items = await read($, running)
    // Agents also match by toolUseId; shells share a notification's, so only by id.
    const key = Object.keys(items).find(k => {
      const i = items[k]!
      return i.id === task?.id || (i.kind === 'agent' && !!task?.toolUseId && i.toolUseId === task.toolUseId)
    })
    if (!key || queued.has(key)) return
    queued.add(key)
    const tone = mapStatus(task?.status)
    $.clock.after(0, () => {
      void finish($, key, tone)
    })
  } catch (err) {
    logOnce($, 'notification', err)
  }
}

/** A background agent started: remember it by `tool_use_id`, learn its id after `next`. */
export async function onAgent($: EngineInterface, e: any, next: (e: any) => any): Promise<any> {
  const key: string | undefined = e.background ? e.tool_use_id : undefined
  try {
    if (key) {
      const at = await $.clock.now()
      const item = { id: key, toolUseId: key, kind: 'agent', label: truncate(e.description, LABEL_MAX), startedAt: at } as const
      await update($, running, r => ({ ...r, [key]: item }))
      await update($, now, () => at)
      await syncTick($)
      await syncAgents($)
    }
  } catch (err) {
    logOnce($, 'agent', err)
  }
  const out = await next(e)
  try {
    if (key && out?.deny) await update($, running, r => without(r, key))
    else if (key && out?.agentId) await update($, running, r => (r[key] ? { ...r, [key]: { ...r[key]!, id: out.agentId } } : r))
    await syncTick($)
    await syncAgents($)
  } catch (err) {
    logOnce($, 'agent', err)
  }

  return out
}

/** Polls `$.agent.list()` every 60 s while an agent runs, as a fallback for a lost notification. */
export async function syncAgents($: EngineInterface): Promise<void> {
  const hasAgent = Object.values(await read($, running)).some(i => i.kind === 'agent')
  if (hasAgent && !pollHandle) {
    pollHandle = $.clock.every(AGENT_POLL_MS, () => {
      void pollAgents($)
    })
  } else if (!hasAgent && pollHandle) {
    pollHandle.cancel()
    pollHandle = null
  }
}

async function pollAgents($: EngineInterface): Promise<void> {
  try {
    const listed = await $.agent.list()
    const items = await read($, running)
    for (const [key, item] of Object.entries(items)) {
      const info = listed.find(a => a.id === item.id)
      if (item.kind !== 'agent' || queued.has(key) || !info || !['completed', 'failed', 'killed'].includes(info.status)) continue
      queued.add(key)
      await finish($, key, mapStatus(info.status))
    }
  } catch (err) {
    logOnce($, 'poll', err)
  }
}

async function finish($: EngineInterface, key: string, tone: Tone): Promise<void> {
  try {
    const item = (await read($, running))[key]
    if (!item) return
    const at = await $.clock.now()
    await update($, running, r => without(r, key))
    if (item.kind === 'agent' && tone === 'failed') {
      const alert = { source: `agent:${item.id}`, kind: 'agent', text: `${item.label} failed` } as const
      await update($, alerts, a => (a.some(x => x.source === alert.source) ? a : [...a, alert]))
    }
    if (item.key && tone === 'ok') await update($, shellFails, f => without(f, item.key!))
    if (item.key && tone === 'failed') await update($, shellFails, f => ({ ...f, [item.key!]: { key: item.key!, label: item.label, at } }))
    toast($, tone, item.label, at)
    await syncTick($)
    await syncAgents($)
  } catch (err) {
    logOnce($, 'finish', err)
  } finally {
    queued.delete(key)
  }
}
