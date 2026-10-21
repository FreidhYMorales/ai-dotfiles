import { expect, test } from 'claude-code/testing'

import { renderBand } from '../hooks/register/band'
import { band, begin, bg, note, world } from './support'

const MIN = 60_000

test('an unknown id changes nothing; a repeated or resumed one is ignored', async ($, on) => {
  const { toasts, clock } = world(on)
  await begin($)
  await bg($, 'make check', 'Run checks')
  expect(await band($, /Run checks/)).toMatch(/Run checks 0s/)
  await note($, clock, 'never-seen', 'failed')
  expect(toasts).toEqual([])

  await note($, clock, 'b1', 'completed')
  await note($, clock, 'b1', 'completed')
  expect(toasts).toHaveLength(1)
  expect(toasts[0]).toMatch(/Run checks/)
  expect(await band($, /Run checks/)).toBeUndefined()
})

test('a failure leaves a dim row until the same command passes', async ($, on) => {
  const { toasts, clock } = world(on)
  await begin($)
  await bg($, 'cd /x && make check', 'Run checks')
  await note($, clock, 'b1', 'failed')
  expect(toasts[0]).toMatch(/failed/)
  expect(await band($, /Run checks failed \d\d:\d\d/)).toBeDefined()

  await bg($, 'make check', 'Run checks again')
  await note($, clock, 'b2', 'completed')
  expect(await band($, /failed/)).toBeUndefined()
})

test('commands sharing a first word but not words 2-3 fail as separate rows', async ($, on) => {
  const { clock } = world(on)
  await begin($)
  await bg($, 'make check fast', 'Fast checks')
  await bg($, 'make build all', 'Build all')
  await note($, clock, 'b1', 'failed')
  await note($, clock, 'b2', 'failed')
  expect(await band($, /Fast checks failed/)).toBeDefined()
  expect(await band($, /Build all failed/)).toBeDefined()
})

test('a killed shell gives a stopped toast and no row', async ($, on) => {
  const { toasts, clock } = world(on)
  await begin($)
  await bg($, 'sleep 99', 'Wait')
  await note($, clock, 'b1', 'killed')
  expect(toasts).toHaveLength(1)
  expect(toasts[0]).toMatch(/stopped/)
  expect(await band($, /Wait|failed/)).toBeUndefined()
})

// 31 simulated minutes run ~1,860 one-second ticks: slow on a busy CI runner.
test('a shell expires after 30 minutes and a late notification is ignored', { timeoutMs: 30_000 }, async ($, on) => {
  const { toasts, clock } = world(on)
  await begin($)
  await bg($, 'sleep 9999', 'Long job')
  await clock.advance(29 * MIN)
  expect(await band($, /Long job/)).toBeDefined()
  await clock.advance(2 * MIN)
  expect(await band($, /Long job/)).toBeUndefined()

  await note($, clock, 'b1', 'failed')
  expect(toasts).toEqual([])
  expect(await band($, /failed/)).toBeUndefined()
})

test('toasts within 2 s merge into one line', async ($, on) => {
  const { toasts, clock } = world(on)
  await begin($)
  await bg($, 'one', 'First')
  await bg($, 'two', 'Second')
  await note($, clock, 'b1', 'completed')
  await clock.advance(1000)
  await note($, clock, 'b2', 'completed')
  expect(toasts.at(-1)).toMatch(/2 done/)

  await clock.advance(5000)
  await bg($, 'three', 'Third')
  await note($, clock, 'b3', 'completed')
  expect(toasts.at(-1)).toMatch(/Third/)
})

test('the 1 s tick runs only while something runs, and once after session.start twice', async ($, on) => {
  const { clock, written, writes } = world(on)
  await begin($)
  await clock.advance(10_000)
  expect(written.now).toBeUndefined()

  await bg($, 'sleep 5', 'Nap')
  await begin($)
  await begin($)
  writes.length = 0
  await clock.advance(1000)
  expect(writes.filter(k => k === 'now')).toHaveLength(1)
  expect(written.now).toBeGreaterThanOrEqual(clock.now())
  // Items live in the host's state, not in the module: a new instance finds them.
  expect(Object.keys(written.running as object)).toEqual(['b1'])
})

test('a throwing render falls back to next(e) and logs once', async () => {
  const logs: string[] = []
  const $ = {
    state: {
      get: async () => {
        throw new Error('boom')
      },
    },
    ui: { log: (text: string) => logs.push(text) },
  }
  const e = { props: { hasSurvey: false, maxRows: 6, bodyColumns: 80 } }
  const next = (x: unknown) => ({ yielded: x })

  expect(await renderBand($ as never, e, next)).toEqual({ yielded: e })
  expect(await renderBand($ as never, e, next)).toEqual({ yielded: e })
  expect(logs).toHaveLength(1)
})
