// CI of the current branch's open PR, from `gh pr view --json
// number,state,headRefOid,statusCheckRollup`. Pure: no `$`.
export type CheckState = 'pending' | 'ok' | 'failed'
export type Check = { name: string; state: CheckState }
// The shared `$.store` entry `look:ci:<root>:<branch>`; `pr: 0` means no open PR.
export type CiEntry = { at: number; pr: number; headSha: string; checks: Check[] }

export const PENDING_TTL_MS = 60_000
export const IDLE_TTL_MS = 5 * 60_000

export const cacheKey = (root: string, branch: string): string => `look:ci:${root}:${branch}`
export const ciId = (root: string, branch: string, pr: number): string => `ci:${root}:${branch}:${pr}`

const OK_CONCLUSIONS = ['SUCCESS', 'NEUTRAL', 'SKIPPED']
const PENDING_STATES = ['PENDING', 'EXPECTED']

/** CheckRun (`status`/`conclusion`) and StatusContext (`state`) to one shape; unknown entries are dropped. */
export function normalizeRollup(rollup: unknown): Check[] {
  if (!Array.isArray(rollup)) return []
  const out: Check[] = []
  for (const c of rollup as Record<string, unknown>[]) {
    if (typeof c?.name === 'string' && typeof c.status === 'string') {
      const state = c.status !== 'COMPLETED' ? 'pending' : OK_CONCLUSIONS.includes(String(c.conclusion)) ? 'ok' : 'failed'
      out.push({ name: c.name, state })
    } else if (typeof c?.context === 'string' && typeof c.state === 'string') {
      out.push({ name: c.context, state: c.state === 'SUCCESS' ? 'ok' : PENDING_STATES.includes(c.state) ? 'pending' : 'failed' })
    }
  }

  return out
}

/**
 * Reads a `gh pr view` result. An open PR gives its entry; no PR ("no pull
 * requests found") or one that is not open gives `pr: 0`; any other failure
 * gives undefined, so the caller keeps what it knew.
 */
export function parseGh(res: { exitCode: number; stdout: string; stderr: string }, at: number): CiEntry | undefined {
  const none = { at, pr: 0, headSha: '', checks: [] }
  if (res.exitCode !== 0) return /no pull requests found/i.test(res.stderr) ? none : undefined
  try {
    const j = JSON.parse(res.stdout) as { number?: unknown; state?: unknown; headRefOid?: unknown; statusCheckRollup?: unknown }
    if (typeof j.number !== 'number' || typeof j.state !== 'string' || typeof j.headRefOid !== 'string') return undefined

    return j.state === 'OPEN' ? { at, pr: j.number, headSha: j.headRefOid, checks: normalizeRollup(j.statusCheckRollup) } : none
  } catch {
    return undefined
  }
}

export function summarize(checks: Check[]): { state: CheckState; failing: string[] } {
  const failing = checks.filter(c => c.state === 'failed').map(c => c.name)

  return { state: failing.length ? 'failed' : checks.some(c => c.state === 'pending') ? 'pending' : 'ok', failing }
}

/** A cache entry is fresh for 60 s while checks are pending, 5 min otherwise. */
export function isFresh(entry: CiEntry, now: number): boolean {
  const ttl = summarize(entry.checks).state === 'pending' ? PENDING_TTL_MS : IDLE_TTL_MS

  return now - entry.at < ttl
}

/** A store value that is not a well-formed entry is ignored. */
export function asEntry(v: unknown): CiEntry | undefined {
  const e = v as Partial<CiEntry> | undefined

  return typeof e?.at === 'number' && typeof e.pr === 'number' && typeof e.headSha === 'string' && Array.isArray(e.checks) ? (e as CiEntry) : undefined
}

export const alertText = (pr: number, failing: string[]): string => `CI #${pr} · ${failing.length === 1 ? failing[0] : `${failing.length} checks`} failed`
