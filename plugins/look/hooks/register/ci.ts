import type { EngineInterface } from 'claude-code'
import { atom, update } from 'claude-code'

import { alertText, asEntry, cacheKey, ciId, isFresh, parseGh, summarize } from '../lib/ci'
import type { CiEntry } from '../lib/ci'
import { logOnce, syncTick } from './timers'

// The validator reads atoms only where they are declared in the same file, so
// each file declares the few it uses (same keys, same initials).
const running = atom({ plugin: 'look', key: 'running' } as const, {})
const alerts = atom({ plugin: 'look', key: 'alerts' } as const, [])
const ci = atom({ plugin: 'look', key: 'ci' } as const, null)
const now = atom({ plugin: 'look', key: 'now' } as const, 0)

const POLL_MS = 60_000
const RUN_MS = 10_000
// Only a handle: a reload drops it with the old timers; the next session.start starts one again.
let pollHandle: { cancel: () => void } | null = null
let inFlight = false
let again = false

/** Starts the 60 s check once (it polls gh only when the shared cache is stale) and polls soon. */
export function startCiPoll($: EngineInterface): void {
  pollHandle ??= $.clock.every(POLL_MS, () => {
    void pollCi($)
  })
  $.clock.after(0, () => {
    void pollCi($)
  })
}

/** One poll at a time: a request during a poll runs once more when it ends. */
export async function pollCi($: EngineInterface): Promise<void> {
  if (inFlight) {
    again = true

    return
  }
  inFlight = true
  try {
    do {
      again = false
      await pollOnce($)
    } while (again)
  } catch (err) {
    logOnce($, 'ci', err)
  } finally {
    inFlight = false
  }
}

async function pollOnce($: EngineInterface): Promise<void> {
  const git = (argv: string[], cwd: string) => $.process.run(['git', ...argv], { cwd, timeoutMs: RUN_MS })
  const top = await git(['rev-parse', '--show-toplevel'], await $.session.cwd())
  const root = top.stdout.trim()
  if (top.exitCode !== 0 || !root) return apply($, null)
  const head = await git(['-C', root, 'rev-parse', '--abbrev-ref', 'HEAD'], root)
  const branch = head.stdout.trim()
  if (head.exitCode !== 0 || !branch || branch === 'HEAD') return apply($, null)

  const at = await $.clock.now()
  const key = cacheKey(root, branch)
  let entry = asEntry(await $.store.get(key))
  if (!entry || !isFresh(entry, at)) {
    try {
      entry = parseGh(await $.process.run(['gh', 'pr', 'view', branch, '--json', 'number,state,headRefOid,statusCheckRollup'], { cwd: root, timeoutMs: RUN_MS }), at)
    } catch (err) {
      logOnce($, 'ci', err)
    }
    // gh missing, failing or timing out: keep what this branch showed, add nothing.
    if (!entry) return apply($, { root, branch })
    await $.store.set(key, entry)
  }
  await apply($, { root, branch, entry })
}

/**
 * Makes the atoms show this entry. Without an entry (gh failed), what belongs to
 * the same root and branch stays; without a target, no CI state stays.
 */
async function apply($: EngineInterface, target: { root: string; branch: string; entry?: CiEntry } | null): Promise<void> {
  const entry = target?.entry
  const want = target && entry && entry.pr > 0 ? { ...summarize(entry.checks), id: ciId(target.root, target.branch, entry.pr), pr: entry.pr, sha: entry.headSha } : null
  const source = want ? `${want.id}:${want.sha}` : ''
  const pending = !!entry?.checks.some(c => c.state === 'pending')
  const mine = (s: string): boolean => !!target && s.startsWith(`ci:${target.root}:${target.branch}:`)
  const at = await $.clock.now()

  await update($, ci, c =>
    target && want ? { root: target.root, branch: target.branch, pr: want.pr, headSha: want.sha, state: want.state, failing: want.failing } : !entry && c && mine(`ci:${c.root}:${c.branch}:`) ? c : null,
  )
  await update($, alerts, a => {
    const kept = a.filter(x => x.kind !== 'ci' || (entry ? want?.state === 'failed' && x.source === source : mine(x.source)))
    const add = want?.state === 'failed' && !kept.some(x => x.source === source)

    return add ? [...kept, { source, kind: 'ci', text: alertText(want.pr, want.failing) } as const] : kept
  })
  await update($, running, r => {
    const kept = Object.fromEntries(Object.entries(r).filter(([k, i]) => i.kind !== 'ci' || (entry ? pending && k === want?.id : mine(k))))

    return want && pending && !kept[want.id] ? { ...kept, [want.id]: { id: want.id, kind: 'ci', label: `CI #${want.pr}`, startedAt: at } as const } : kept
  })
  await update($, now, () => at)
  await syncTick($)
}
