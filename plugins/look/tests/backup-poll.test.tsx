import { expect, test } from 'claude-code/testing'
import type { On } from 'claude-code'

import { band, begin, memStore, world } from './support'

const MIN = 60_000
const STATE = '/home/u/.local/state/engram-backup'
const CONFIG = '/home/u/.config/restic/engram.env'
// The clock starts at 1_000_000 ms after the epoch.
const T0 = '1970-01-01T00:00:00Z'
const ok = (time = T0) => JSON.stringify({ time, ok: true, failed: [] })
const bad = (time = T0) => JSON.stringify({ time, ok: false, failed: ['/r'] })

// The filesystem and the environment are mocks: nothing here reads the real home.
function disk(on: On, files: Record<string, string | 'deny'>) {
  const reads: string[] = []
  const logs: string[] = []
  on('fs.exists', (_, e) => ({ value: e.path in files }))
  on('fs.read', (_, e) => {
    reads.push(e.path)
    const f = files[e.path]

    return f === undefined || f === 'deny' ? ({ deny: 'EACCES' } as never) : { value: f }
  })
  on('ui.log', (_, e) => {
    logs.push(JSON.stringify(e))

    return { value: undefined } as never
  })

  return { files, reads, logs }
}

async function setup(on: On, $: Parameters<Parameters<typeof test>[1]>[0], files: Record<string, string | 'deny'>, env: Record<string, string> = { HOME: '/home/u' }) {
  const w = world(on)
  Object.assign(w.vars, env)
  const d = disk(on, files)
  const store = memStore(on)
  await begin($)
  await w.clock.settle()

  return { ...w, ...d, store }
}

test('a stale backup raises a red alert; a backup that recovers clears it', { timeoutMs: 30_000 }, async ($, on) => {
  const old = '1969-12-25T00:00:00Z'
  const { clock, files, written } = await setup(on, $, { [CONFIG]: '', [`${STATE}/backup.json`]: ok(old), [`${STATE}/verify.json`]: ok() })
  expect(written.alerts).toEqual([{ source: `backup:backup-stale:${old}`, kind: 'backup', text: expect.stringMatching(/^Last backup was \d+ days ago$/) }])
  files[`${STATE}/backup.json`] = ok()
  await clock.advance(5 * MIN)
  expect(written.alerts).toEqual([])
})

test('a failed backup shows in the band and is polled again every 5 minutes, not before', { timeoutMs: 30_000 }, async ($, on) => {
  const { clock, files, reads } = await setup(on, $, { [CONFIG]: '', [`${STATE}/backup.json`]: bad() })
  expect(await band($, /Backup failed · \/r/)).toBeDefined()
  const before = reads.length
  await clock.advance(4 * MIN)
  expect(reads.length).toBe(before)
  files[`${STATE}/backup.json`] = ok()
  await clock.advance(MIN)
  expect(reads.length).toBeGreaterThan(before)
  expect(await band($, /Backup failed/)).toBeUndefined()
})

test('not configured raises nothing and reads no state', async ($, on) => {
  const { written, reads } = await setup(on, $, { [`${STATE}/backup.json`]: bad() })
  expect(written.alerts ?? []).toEqual([])
  expect(reads).toEqual([])
})

test('configured with nothing recorded raises the no-backup alert', async ($, on) => {
  const { written } = await setup(on, $, { [CONFIG]: '' })
  expect(written.alerts).toEqual([{ source: 'backup:backup-none:never', kind: 'backup', text: 'No backup recorded yet' }])
})

test('XDG variables move both the config and the state paths', async ($, on) => {
  const { written } = await setup(on, $, { '/c/restic/engram.env': '', '/s/engram-backup/backup.json': bad() }, { HOME: '/home/u', XDG_CONFIG_HOME: '/c', XDG_STATE_HOME: '/s' })
  expect((written.alerts as unknown[]).length).toBe(1)
})

test('a blocked or failed secret scan raises an alert', async ($, on) => {
  const scan = JSON.stringify({ mode: 'scan', time: T0, ok: false, findings: 2 })
  const { written } = await setup(on, $, { [CONFIG]: '', [`${STATE}/backup.json`]: ok(), [`${STATE}/verify.json`]: ok(), [`${STATE}/scan.json`]: scan })
  expect(written.alerts).toEqual([{ source: `backup:scan-failed:${T0}`, kind: 'backup', text: 'Secret scan found 2 secrets' }])
})

test('an unreadable file logs once and never crashes', { timeoutMs: 30_000 }, async ($, on) => {
  const { clock, logs, written } = await setup(on, $, { [CONFIG]: '', [`${STATE}/backup.json`]: 'deny' })
  expect(written.alerts).toEqual([{ source: 'backup:backup-failed:', kind: 'backup', text: 'Backup failed · unknown repository' }])
  await clock.advance(10 * MIN)
  expect(logs.filter(l => l.includes('look: backup failed'))).toHaveLength(1)
})

test('a dismissed backup alert stays hidden until a new failure time re-raises it', { timeoutMs: 30_000 }, async ($, on) => {
  const { clock, files, store } = await setup(on, $, { [CONFIG]: '', [`${STATE}/backup.json`]: bad(), [`${STATE}/verify.json`]: ok() })
  expect(await band($, /Backup failed/)).toBeDefined()
  store.set(`look:dismiss:backup:backup-failed:${T0}`, { at: 1_000_000 })
  await clock.advance(10_000)
  expect(await band($, /Backup failed/)).toBeUndefined()
  files[`${STATE}/backup.json`] = bad('1970-01-01T00:10:00Z')
  await clock.advance(5 * MIN)
  expect(await band($, /Backup failed/)).toBeDefined()
})
