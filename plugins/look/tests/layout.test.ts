import { expect, test } from 'claude-code/testing'
import type { LookItem } from '../types/index'
import { G } from '../hooks/lib/glyphs'
import { buildBand, formatElapsed, truncate } from '../hooks/lib/layout'

type Look = Parameters<typeof buildBand>[0]

const item = (id: string, kind: LookItem['kind'], label: string, startedAt = 0): LookItem => ({
  id,
  kind,
  label,
  startedAt,
})

const state = (over: Partial<Look> = {}): Look => ({
  running: {},
  shellFails: {},
  alerts: [],
  ci: null,
  dismissed: [],
  now: 0,
  ...over,
})

const running = (...items: LookItem[]): Record<string, LookItem> =>
  Object.fromEntries(items.map(i => [i.id, i]))

test('glyphs are the plan set A codepoints', async () => {
  expect(G.running.codePointAt(0)).toBe(0xf0453)
  expect(G.agent.codePointAt(0)).toBe(0xf06a9)
  expect(G.shell.codePointAt(0)).toBe(0xf489)
  expect(G.ci.codePointAt(0)).toBe(0xf407)
  expect(G.backup.codePointAt(0)).toBe(0xf0193)
  expect(G.ok.codePointAt(0)).toBe(0xf00c)
  expect(G.fail.codePointAt(0)).toBe(0xf00d)
  expect(G.dim.codePointAt(0)).toBe(0xf01d8)
})

test('truncate never wraps and counts one column per code point', async () => {
  expect(truncate('hello', 5)).toBe('hello')
  expect(truncate('hello world', 6)).toBe('hello…')
  expect(truncate(`${G.shell}abc`, 3)).toBe(`${G.shell}a…`)
  expect(truncate('abc', 1)).toBe('…')
  expect(truncate('abc', 0)).toBe('')
})

test('formatElapsed', async () => {
  expect(formatElapsed(38_000)).toBe('38s')
  expect(formatElapsed(80_000)).toBe('1m20s')
  expect(formatElapsed(242_000)).toBe('4m02s')
  expect(formatElapsed(3_900_000)).toBe('1h05m')
  expect(formatElapsed(-5)).toBe('0s')
})

test('an idle state yields no rows', async () => {
  expect(buildBand(state(), 6, 80, 0)).toEqual([])
})

test('three or fewer items share one line with elapsed after the label', async () => {
  const s = state({
    running: running(item('a', 'agent', 'PR 3 validator'), item('b', 'shell', 'make check')),
  })
  const rows = buildBand(s, 6, 80, 38_000)
  expect(rows.length).toBe(1)
  expect(rows[0]).toMatchObject({
    kind: 'activity',
    text: `${G.agent} PR 3 validator 38s · ${G.shell} make check 38s`,
  })
})

test('more than three items get one row each, oldest first', async () => {
  const s = state({
    running: running(
      item('a', 'agent', 'one', 3000),
      item('b', 'agent', 'two', 1000),
      item('c', 'shell', 'three', 2000),
      item('d', 'ci', 'CI #18', 4000),
    ),
  })
  const rows = buildBand(s, 6, 80, 10_000)
  expect(rows.map(r => r.text)).toEqual([
    `${G.agent} two 9s`,
    `${G.shell} three 8s`,
    `${G.agent} one 7s`,
    `${G.running} CI #18 6s`,
  ])
})

test('rows are capped at maxRows and the rest folds into +N more', async () => {
  const items = ['a', 'b', 'c', 'd', 'e', 'f'].map((id, i) => item(id, 'shell', id, i))
  const rows = buildBand(state({ running: running(...items) }), 4, 80, 10_000)
  expect(rows.length).toBe(4)
  expect(rows[3]).toMatchObject({ kind: 'more', text: '+3 more' })
})

test('labels truncate to bodyColumns minus the two reserved columns', async () => {
  const s = state({ running: running(item('a', 'shell', 'x'.repeat(100))) })
  const [row] = buildBand(s, 6, 40, 0)
  expect(Array.from(row!.text).length).toBe(38)
  expect(row!.text.endsWith('…')).toBe(true)
})

test('alerts come first with hotkeys, dismissed ones are hidden', async () => {
  const s = state({
    alerts: [
      { source: 'ci:1', kind: 'ci', text: 'CI #17 check failed' },
      { source: 'agent:2', kind: 'agent', text: 'agent "x" failed' },
      { source: 'backup:3', kind: 'backup', text: 'backup stale' },
    ],
    dismissed: ['agent:2'],
  })
  const rows = buildBand(s, 6, 80, 0)
  expect(rows.map(r => [r.kind, r.source, r.hotkey])).toEqual([
    ['alert', 'ci:1', 1],
    ['alert', 'backup:3', 2],
  ])
  expect(rows[0]!.text).toBe(`${G.fail} CI #17 check failed`)
})

test('shell failures are dim rows with the time', async () => {
  const at = new Date(2026, 0, 1, 12, 3).getTime()
  const s = state({ shellFails: { k: { key: 'make check', label: 'make check', at } } })
  const rows = buildBand(s, 6, 80, 0)
  expect(rows).toEqual([{ kind: 'fail', text: `${G.dim} make check failed 12:03` }])
})

test('alerts, rows and activity share the maxRows budget', async () => {
  const s = state({
    alerts: [{ source: 'a', kind: 'ci', text: 'one' }],
    shellFails: { k: { key: 'k', label: 'k', at: 0 } },
    running: running(item('a', 'shell', 'x')),
  })
  const rows = buildBand(s, 2, 80, 0)
  expect(rows.map(r => r.kind)).toEqual(['alert', 'more'])
  expect(rows[1]!.text).toBe('+2 more')
})
