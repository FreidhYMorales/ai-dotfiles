import { expect, test } from 'claude-code/testing'
import type { Engine, On } from 'claude-code'

import { band, begin, memStore, world } from './support'

const MIN = 60_000
const NOW = 1_000_000
const run = (name: string, status: string, conclusion: string) => ({ __typename: 'CheckRun', name, status, conclusion })
const FAIL = [run('lint', 'COMPLETED', 'FAILURE')]
const PASS = [run('lint', 'COMPLETED', 'SUCCESS')]
const WAIT = [run('lint', 'IN_PROGRESS', '')]
const KEY = 'look:ci:/w/My Repo:main'
const out = (exitCode: number, stdout = '', stderr = '') =>
  ({ value: { exitCode, stdout, stderr, isStdoutTruncated: false, isStderrTruncated: false } }) as never

// git and gh stand in as `process.run` hooks; `deny` makes the call reject.
type Init = Partial<{ root: string | null; branch: string; gh: string; checks: object[]; gate: Promise<void> | null }>
function repo(on: On, init: Init) {
  const env = { cwd: '/w/My Repo/sub', root: '/w/My Repo' as string | null, branch: 'main', gh: 'ok', state: 'OPEN', checks: FAIL as object[], gate: null as Promise<void> | null, ...init }
  const calls: { argv: readonly string[]; cwd?: string }[] = []
  const logs: unknown[] = []
  on('classic.CwdChanged', () => ({}) as never)
  on('session.cwd', () => ({ value: env.cwd }))
  on('ui.log', () => {
    logs.push(1)

    return { value: undefined } as never
  })
  on('process.run', async (_, e) => {
    calls.push({ argv: e.argv, cwd: e.init?.cwd })
    if (e.argv[0] === 'git') {
      if (e.argv.includes('--show-toplevel')) return env.root ? out(0, `${env.root}\n`) : out(128, '', 'fatal: not a git repository')

      return out(0, `${env.branch}\n`)
    }
    await env.gate
    if (env.gh === 'deny') return { deny: 'gh missing' } as never
    if (env.gh === 'fail') return out(1, '', 'HTTP 401')
    if (env.gh === 'none') return out(1, '', 'no pull requests found for branch "main"')

    return out(0, JSON.stringify({ number: 17, state: env.state, headRefOid: 's1', statusCheckRollup: env.checks }))
  })

  return { env, calls, logs, gh: () => calls.filter(c => c.argv[0] === 'gh').length }
}

async function setup($: Engine, on: On, init: Init = {}, entries: Record<string, unknown> = {}) {
  const w = world(on)
  const r = repo(on, init)
  const store = memStore(on, entries)
  await begin($)
  await w.clock.settle()

  return { ...w, ...r, store }
}

test('a failing check on the open PR raises a keyed alert; argv and cwd are passed without a shell', async ($, on) => {
  const { calls, store, written } = await setup($, on)
  expect(calls[0]).toEqual({ argv: ['git', 'rev-parse', '--show-toplevel'], cwd: '/w/My Repo/sub' })
  expect(calls[1]).toEqual({ argv: ['git', '-C', '/w/My Repo', 'rev-parse', '--abbrev-ref', 'HEAD'], cwd: '/w/My Repo' })
  expect(calls[2]).toEqual({ argv: ['gh', 'pr', 'view', 'main', '--json', 'number,state,headRefOid,statusCheckRollup'], cwd: '/w/My Repo' })
  expect(written.alerts).toEqual([{ source: 'ci:/w/My Repo:main:17:s1', kind: 'ci', text: 'CI #17 · lint failed' }])
  expect(await band($, /CI #17 · lint failed/)).toBeDefined()
  expect(store.get(KEY)).toEqual({ at: NOW, pr: 17, headSha: 's1', checks: [{ name: 'lint', state: 'failed' }] })
})

test('pending checks show as running CI and are re-polled after 60 s', { timeoutMs: 30_000 }, async ($, on) => {
  const { gh, clock } = await setup($, on, { checks: WAIT })
  expect(await band($, /CI #17 \d/)).toBeDefined()
  const before = gh()
  await clock.advance(MIN)
  expect(gh()).toBe(before + 1)
})

test('recovery removes the alert once the cache is stale', { timeoutMs: 30_000 }, async ($, on) => {
  const { env, gh, clock } = await setup($, on)
  env.checks = PASS
  await clock.advance(4 * MIN)
  expect(gh()).toBe(1)
  expect(await band($, /lint failed/)).toBeDefined()
  await clock.advance(MIN)
  expect(gh()).toBe(2)
  expect(await band($, /lint failed/)).toBeUndefined()
})

const entry = (age: number, state: string) => ({ at: NOW - age, pr: 17, headSha: 's1', checks: [{ name: 'lint', state }] })
for (const [age, state, calls] of [[MIN - 1, 'pending', 0], [MIN + 1, 'pending', 1], [MIN + 1, 'failed', 0], [5 * MIN + 1, 'failed', 1]] as const) {
  test(`a ${state} shared cache ${age}ms old ${calls ? 'is polled again' : 'is read without calling gh'}`, async ($, on) => {
    const { gh } = await setup($, on, {}, { [KEY]: entry(age, state) })
    expect(gh()).toBe(calls)
  })
}

test('a branch switch, detached HEAD or a closed PR drops the alert', { timeoutMs: 30_000 }, async ($, on) => {
  const { env, clock } = await setup($, on)
  expect(await band($, /lint failed/)).toBeDefined()
  env.branch = 'other'
  env.gh = 'none'
  await clock.advance(MIN)
  expect(await band($, /lint failed/)).toBeUndefined()
  env.branch = 'main'
  env.gh = 'ok'
  await clock.advance(5 * MIN)
  expect(await band($, /lint failed/)).toBeDefined()
  env.branch = 'HEAD'
  await clock.advance(MIN)
  expect(await band($, /lint failed/)).toBeUndefined()
  env.branch = 'main'
  env.state = 'MERGED'
  await clock.advance(5 * MIN)
  expect(await band($, /lint failed/)).toBeUndefined()
})

test('outside a repository there is no CI and gh is never called; a cwd change finds the repo', async ($, on) => {
  const { env, gh, clock } = await setup($, on)
  env.root = null
  await clock.advance(5 * MIN)
  expect(await band($, /CI/)).toBeUndefined()
  expect(gh()).toBe(1)
  env.root = '/w/My Repo'
  await $.classic.CwdChanged({ old_cwd: '/tmp', new_cwd: '/w/My Repo' } as never)
  await clock.settle()
  expect(await band($, /lint failed/)).toBeDefined()
})

test('gh missing, failing or timing out keeps the last alert and logs at most once', { timeoutMs: 30_000 }, async ($, on) => {
  const { env, clock, logs } = await setup($, on)
  for (const mode of ['deny', 'fail']) {
    env.gh = mode
    await clock.advance(5 * MIN)
    expect(await band($, /lint failed/)).toBeDefined()
  }
  expect(logs.length <= 1).toBe(true)
})

test('gh missing on a repo with no earlier alert adds nothing', async ($, on) => {
  await setup($, on, { gh: 'deny' })
  expect(await band($, /CI/)).toBeUndefined()
})

test('one gh call is in flight at a time', { timeoutMs: 30_000 }, async ($, on) => {
  let release = () => {}
  const gate = new Promise<void>(res => (release = res))
  const { gh, clock } = await setup($, on, { gate })
  await clock.advance(3 * MIN)
  expect(gh()).toBe(1)
  release()
  await clock.settle()
  expect(gh()).toBe(1)
})
