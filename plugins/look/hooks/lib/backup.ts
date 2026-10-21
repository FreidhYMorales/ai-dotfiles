// The rules of the toolkit `backup-status` hook over the files bin/engram-backup
// writes (backup.json, verify.json, scan.json). Pure: no `$`.
import type { LookAlert } from 'claude-code'

const DAY_MS = 86_400_000
const MAX_BACKUP_DAYS = 2
const MAX_VERIFY_DAYS = 8

type Env = { HOME?: string; XDG_STATE_HOME?: string; XDG_CONFIG_HOME?: string }
/** File contents; undefined when the file does not exist. */
export type BackupInput = { now: number; configured: boolean; backup?: string; verify?: string; scan?: string }

// `${VAR:-fallback}`: an empty variable counts as unset. No HOME and no XDG: no path.
const base = (xdg: string | undefined, home: string | undefined, rest: string): string | undefined => (xdg ? xdg : home ? `${home}/${rest}` : undefined)

export function stateDir(env: Env): string | undefined {
  const root = base(env.XDG_STATE_HOME, env.HOME, '.local/state')

  return root && `${root}/engram-backup`
}

export function configPath(env: Env): string | undefined {
  const root = base(env.XDG_CONFIG_HOME, env.HOME, '.config')

  return root && `${root}/restic/engram.env`
}

type Status = { ok?: unknown; time?: unknown; failed?: unknown; findings?: unknown; error?: unknown }

// jq on a broken file yields no `.ok`, so the hook reports it as failed.
function parse(text: string): Status {
  try {
    const j: unknown = JSON.parse(text)

    return j && typeof j === 'object' ? (j as Status) : {}
  } catch {
    return {}
  }
}

const alert = (rule: string, time: string, text: string): LookAlert => ({ source: `backup:${rule}:${time}`, kind: 'backup', text })

/** The alerts the state files call for; the source carries rule and time, so a new failure re-raises. */
export function backupRules(input: BackupInput): LookAlert[] {
  if (!input.configured) return []
  const out: LookAlert[] = []
  const check = (mode: 'backup' | 'verify', text: string | undefined, maxDays: number, label: string): void => {
    if (text === undefined) return void (mode === 'backup' && out.push(alert('backup-none', 'never', 'No backup recorded yet')))
    const s = parse(text)
    const time = typeof s.time === 'string' ? s.time : ''
    if (s.ok !== true) {
      const failed = Array.isArray(s.failed) ? s.failed.filter((f): f is string => typeof f === 'string').join(', ') : ''
      return void out.push(alert(`${mode}-failed`, time, `${label} failed · ${failed || 'unknown repository'}`))
    }
    const days = Math.floor((input.now - (Date.parse(time) || 0)) / DAY_MS)
    if (days > maxDays) out.push(alert(`${mode}-stale`, time, mode === 'backup' ? `Last backup was ${days} days ago` : `Backup last verified ${days} days ago`))
  }
  check('backup', input.backup, MAX_BACKUP_DAYS, 'Backup')
  check('verify', input.verify, MAX_VERIFY_DAYS, 'Backup verify')
  if (input.scan !== undefined) {
    const s = parse(input.scan)
    if (s.ok !== true) {
      const n = typeof s.findings === 'number' ? s.findings : 0
      out.push(alert('scan-failed', typeof s.time === 'string' ? s.time : '', s.error || n === 0 ? 'Secret scan could not run' : `Secret scan found ${n} secret${n === 1 ? '' : 's'}`))
    }
  }

  return out
}
