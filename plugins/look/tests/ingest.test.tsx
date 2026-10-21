import { expect, mock, test } from 'claude-code/testing'
import type { Engine, On } from 'claude-code'

import { renderBand } from '../hooks/register/band'

const MIN = 60_000

// Nothing draws beneath the plugin: the hooks here stand for the engine.
function world(on: On) {
  const toasts: string[] = []
  // What the plugin wrote to its atoms: the host's copy, seen from outside.
  const written: Record<string, unknown> = {}
  const writes: string[] = []
  let seq = 0
  const clock = mock.clock(on, { now: 1_000_000 })
  on('session.start', (_, e) => ({ cwd: e.cwd }))
  on('tool.call', () => ({
    result: { stdout: '', stderr: '', interrupted: false, backgroundTaskId: `b${(seq += 1)}` },
  }))
  on('ui.toast', (_, e) => {
    toasts.push(e.text)

    return { value: undefined }
  })
  on('state.set', { plugin: 'look' }, (_, e, next) => {
    written[e.key] = e.value
    writes.push(e.key)

    return next(e)
  })
  on('ui.render', ($, e) => {
    const { Text } = $.ui.resolve(e)

    return <Text>engine</Text>
  })

  return { toasts, clock, written, writes }
}

let n = 0
const bg = ($: Engine, command: string, description?: string) =>
  $.tool.call({ tool: 'Bash', command, description, run_in_background: true })
const begin = ($: Engine) => $.session.start({ cwd: '/', surface: 'terminal', isInteractive: true })

async function note($: Engine, clock: { settle: () => Promise<void> }, id: string, status: string) {
  const task = { id, status, toolUseId: 'tu' }
  const props = { text: '', origin: { kind: 'task-notification' }, isExpanded: false, task }
  const ui = await $.ui.mount({ plugin: 'look', component: 'UserMessage', requestId: `n${(n += 1)}`, surface: 'terminal', props } as never)
  await clock.settle()
  await ui.unmount()
}

async function band($: Engine, re: RegExp) {
  const props = { hasSurvey: false, isWorking: false, maxRows: 6, bodyColumns: 80, scroll: { offset: 0, bodyRows: 6 }, view: {} }
  const ui = await $.ui.mount({ plugin: 'look', component: 'AbovePrompt', requestId: `b${(n += 1)}`, surface: 'terminal', props } as never)
  const found = (await ui.find({ type: 'Text', text: re }))?.text
  await ui.unmount()

  return found
}

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

test('a killed shell gives a stopped toast and no row', async ($, on) => {
  const { toasts, clock } = world(on)
  await begin($)
  await bg($, 'sleep 99', 'Wait')
  await note($, clock, 'b1', 'killed')
  expect(toasts).toHaveLength(1)
  expect(toasts[0]).toMatch(/stopped/)
  expect(await band($, /Wait|failed/)).toBeUndefined()
})

test('a shell expires after 30 minutes and a late notification is ignored', async ($, on) => {
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
