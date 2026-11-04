import { expect, test } from 'claude-code/testing'
import type { Engine } from 'claude-code'

import { MAX_AGE_MS, dismissKey, splitDismissals } from '../hooks/lib/dismiss'
import { band, begin, bg, memStore, mountBand, note, world } from './support'

const DAY = 24 * 60 * 60_000
const NOW = 1_000_000

// An agent that ends `failed` raises the alert `agent:a<n>`.
let tu = 0
async function fail($: Engine, clock: { settle: () => Promise<void> }, n: number) {
  const id = `tu${(tu += 1)}`
  await $.agent.spawn({ prompt: 'p', description: `Job ${n}`, background: true, tool_use_id: id } as never)
  await note($, clock, `a${n}`, 'failed', id)
}

test('prune splits live sources from keys older than 30 days', () => {
  const keys = [
    { key: dismissKey('agent:a1'), at: NOW - 5 * DAY },
    { key: dismissKey('ci:x'), at: NOW - MAX_AGE_MS - 1 },
    { key: dismissKey('backup:r:1'), at: undefined },
    { key: 'look:ci:/r:main', at: 1 },
  ]
  expect(splitDismissals(keys, NOW)).toEqual({ live: ['agent:a1'], stale: [dismissKey('ci:x'), dismissKey('backup:r:1')] })
})

test('a digit hotkey press dismisses that alert and writes its store key', { timeoutMs: 30_000 }, async ($, on) => {
  const { clock } = world(on)
  const store = memStore(on)
  await begin($)
  await fail($, clock, 1)
  await fail($, clock, 2)
  const ui = await mountBand($)
  expect((await ui.find({ key: 'dismiss:agent:a1' }))?.text).toMatch(/1/)
  await ui.press({ key: 'dismiss:agent:a1' })
  await clock.settle()
  await ui.unmount()

  expect([...store.keys()]).toEqual([dismissKey('agent:a1')])
  expect(store.get(dismissKey('agent:a1'))).toEqual({ at: NOW })
  expect(await band($, /Job 1 failed/)).toBeUndefined()
  expect(await band($, /Job 2 failed/)).toBeDefined()
})

test('a dismissal written by another session clears the alert on the 5 s tick', { timeoutMs: 30_000 }, async ($, on) => {
  const { clock } = world(on)
  const store = memStore(on)
  await begin($)
  await fail($, clock, 1)
  expect(await band($, /Job 1 failed/)).toBeDefined()
  store.set(dismissKey('agent:a1'), { at: NOW })
  await clock.advance(5000)
  expect(await band($, /Job 1 failed/)).toBeUndefined()
})

test('a dismissed source stays quiet and a new failing one re-raises', { timeoutMs: 30_000 }, async ($, on) => {
  const { clock } = world(on)
  const store = memStore(on, { [dismissKey('agent:a1')]: { at: NOW } })
  await begin($)
  await clock.advance(5000)
  await fail($, clock, 1)
  expect(await band($, /Job 1 failed/)).toBeUndefined()
  await fail($, clock, 2)
  expect(await band($, /Job 2 failed/)).toBeDefined()
})

test('the tick deletes dismissal keys older than 30 days and keeps the rest', { timeoutMs: 30_000 }, async ($, on) => {
  const { clock } = world(on)
  const store = memStore(on, {
    [dismissKey('agent:old')]: { at: NOW - 31 * DAY },
    [dismissKey('agent:new')]: { at: NOW - DAY },
    'look:ci:/r:main': { at: 1 },
  })
  await begin($)
  await clock.advance(5000)
  expect([...store.keys()].sort()).toEqual(['look:ci:/r:main', dismissKey('agent:new')].sort())
})

test('/band clear dismisses every alert and clears running items and shell failures', { timeoutMs: 30_000 }, async ($, on) => {
  const { clock } = world(on)
  const store = memStore(on)
  await begin($)
  await fail($, clock, 1)
  await fail($, clock, 2)
  await bg($, 'sleep 99', 'Wait')
  await bg($, 'false', 'Boom')
  await note($, clock, 'b2', 'failed')
  expect(await band($, /Wait/)).toBeDefined()
  await $.command.run({ command: 'band', args: 'clear' })
  await clock.settle()

  expect([...store.keys()].sort()).toEqual([dismissKey('agent:a1'), dismissKey('agent:a2')])
  for (const re of [/Job \d failed/, /Wait/, /Boom/]) expect(await band($, re)).toBeUndefined()
})
