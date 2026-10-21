import { expect, test } from 'claude-code/testing'

import { backupRules, stateDir, configPath } from '../hooks/lib/backup'

const DAY = 86_400_000
const T0 = '2026-01-10T00:00:00Z'
const NOW = Date.parse(T0) + DAY
const ok = (time: string, extra = {}) => JSON.stringify({ mode: 'backup', time, ok: true, failed: [], ...extra })
const bad = (time: string, failed: string[]) => JSON.stringify({ time, ok: false, failed })
const rules = (p: Partial<Parameters<typeof backupRules>[0]> = {}) => backupRules({ now: NOW, configured: true, backup: ok(T0), verify: ok(T0), ...p })

test('paths follow XDG with the HOME fallback, an empty variable counting as unset', () => {
  expect(stateDir({ HOME: '/h' })).toBe('/h/.local/state/engram-backup')
  expect(stateDir({ HOME: '/h', XDG_STATE_HOME: '/s' })).toBe('/s/engram-backup')
  expect(stateDir({ HOME: '/h', XDG_STATE_HOME: '' })).toBe('/h/.local/state/engram-backup')
  expect(configPath({ HOME: '/h' })).toBe('/h/.config/restic/engram.env')
  expect(configPath({ XDG_CONFIG_HOME: '/c' })).toBe('/c/restic/engram.env')
  expect(stateDir({})).toBeUndefined()
})

test('a healthy, recent backup and verify raise nothing', () => {
  expect(rules()).toEqual([])
})

test('not configured raises nothing, whatever the state says', () => {
  expect(rules({ configured: false, backup: bad(T0, ['r']), scan: '{"ok":false}' })).toEqual([])
  expect(rules({ configured: false, backup: undefined })).toEqual([])
})

test('a failed backup names the failed repositories, keyed by rule and time', () => {
  expect(rules({ backup: bad(T0, ['a', 'b']) })).toEqual([{ source: `backup:backup-failed:${T0}`, kind: 'backup', text: 'Backup failed · a, b' }])
  expect(rules({ backup: bad(T0, []) })[0]?.text).toBe('Backup failed · unknown repository')
})

test('a failed verify is its own rule', () => {
  expect(rules({ verify: bad(T0, ['a']) })).toEqual([{ source: `backup:verify-failed:${T0}`, kind: 'backup', text: 'Backup verify failed · a' }])
})

test('ages count whole days: a backup stays quiet at 2 days and alerts at 3, a verify at 9', () => {
  expect(rules({ now: Date.parse(T0) + 3 * DAY - 1 })).toEqual([])
  expect(rules({ now: Date.parse(T0) + 3 * DAY, verify: ok(T0) })).toEqual([{ source: `backup:backup-stale:${T0}`, kind: 'backup', text: 'Last backup was 3 days ago' }])
  expect(rules({ now: Date.parse(T0) + 8 * DAY + DAY - 1, backup: ok(T0) }).map(a => a.source)).toEqual([`backup:backup-stale:${T0}`])
  expect(rules({ now: Date.parse(T0) + 9 * DAY, backup: ok('2026-01-18T00:00:00Z') })).toEqual([{ source: `backup:verify-stale:${T0}`, kind: 'backup', text: 'Backup last verified 9 days ago' }])
})

test('no backup recorded raises one alert; a missing verify raises none', () => {
  expect(rules({ backup: undefined, verify: undefined })).toEqual([{ source: 'backup:backup-none:never', kind: 'backup', text: 'No backup recorded yet' }])
})

test('an unparseable file counts as failed and an unparseable time as stale, as in the hook', () => {
  expect(rules({ backup: 'not json' })).toEqual([{ source: 'backup:backup-failed:', kind: 'backup', text: 'Backup failed · unknown repository' }])
  expect(rules({ backup: ok('garbage') }).map(a => a.source)).toEqual(['backup:backup-stale:garbage'])
})

test('a failed or blocked secret scan is an alert; an ok scan or none is not', () => {
  const scan = (o: object) => JSON.stringify({ mode: 'scan', time: T0, ...o })
  expect(rules({ scan: scan({ ok: false, findings: 3 }) })).toEqual([{ source: `backup:scan-failed:${T0}`, kind: 'backup', text: 'Secret scan found 3 secrets' }])
  expect(rules({ scan: scan({ ok: false, findings: 1 }) })[0]?.text).toBe('Secret scan found 1 secret')
  expect(rules({ scan: scan({ ok: false, findings: 0, error: 'scan could not run' }) })[0]?.text).toBe('Secret scan could not run')
  expect(rules({ scan: scan({ ok: true, findings: 0 }) })).toEqual([])
  expect(rules({ scan: undefined })).toEqual([])
})

test('a new failure time gives a new source, so a dismissal does not hide it', () => {
  const a = rules({ backup: bad(T0, ['r']) })[0]?.source
  const b = rules({ backup: bad('2026-01-11T00:00:00Z', ['r']) })[0]?.source
  expect(a).not.toBe(b)
})
