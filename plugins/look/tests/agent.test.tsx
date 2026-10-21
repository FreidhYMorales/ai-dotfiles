import { expect, test } from 'claude-code/testing'
import type { Engine } from 'claude-code'

import { band, begin, bg, note, world } from './support'

const MIN = 60_000

const spawn = ($: Engine, toolUseId: string, description = 'Review diff') =>
  $.agent.spawn({ prompt: 'p', description, background: true, tool_use_id: toolUseId } as never)

test('a background spawn adds a running item by its tool_use_id; a foreground one does not', async ($, on) => {
  world(on)
  await begin($)
  await $.agent.spawn({ prompt: 'p', description: 'Quick look', background: false, tool_use_id: 'tuF' } as never)
  expect(await band($, /Quick look/)).toBeUndefined()

  await spawn($, 'tuA')
  expect(await band($, /Review diff/)).toMatch(/Review diff 0s/)
})

test('a denied spawn leaves no item', async ($, on) => {
  world(on).spawnReply.deny = 'no'
  await begin($)
  await spawn($, 'tuA')
  expect(await band($, /Review diff/)).toBeUndefined()
})

test('a failed agent raises a pinned alert that outlives the item', async ($, on) => {
  const { toasts, clock, written } = world(on)
  await begin($)
  await spawn($, 'tuA')
  await note($, clock, 'a1', 'failed', 'tuA')
  expect(toasts[0]).toMatch(/Review diff failed/)
  expect(written.alerts).toEqual([{ source: 'agent:a1', kind: 'agent', text: 'Review diff failed' }])
  await clock.advance(5 * MIN)
  expect(await band($, /Review diff failed/)).toBeDefined()
  // A second notification for the same agent adds nothing.
  await note($, clock, 'a1', 'failed', 'tuA')
  expect(written.alerts).toHaveLength(1)
})

test('completed and killed agents toast without an alert', async ($, on) => {
  const { toasts, clock, written } = world(on)
  await begin($)
  await spawn($, 'tuA', 'First')
  await spawn($, 'tuB', 'Second')
  await note($, clock, 'a1', 'completed', 'tuA')
  expect(toasts.at(-1)).toMatch(/First done/)
  await clock.advance(5000)
  await note($, clock, 'a2', 'killed', 'tuB')
  expect(toasts.at(-1)).toMatch(/Second stopped/)
  expect(written.alerts ?? []).toEqual([])
})

test('an old notification after a resume creates no alert', async ($, on) => {
  const { toasts, clock, written } = world(on)
  await begin($)
  await note($, clock, 'a9', 'failed', 'tuOld')
  expect(toasts).toEqual([])
  expect(written.alerts ?? []).toEqual([])
})

test('the 60 s agent.list poll finishes an agent whose notification never came', async ($, on) => {
  const { toasts, clock, written, agents } = world(on)
  await begin($)
  await spawn($, 'tuA', 'Slow')
  await spawn($, 'tuB', 'Broken')
  agents.push({ id: 'a1', status: 'running' }, { id: 'a2', status: 'running' })
  await clock.advance(MIN)
  expect(await band($, /Slow/)).toBeDefined()
  expect(toasts).toEqual([])

  agents[0]!.status = 'completed'
  agents[1]!.status = 'failed'
  await clock.advance(MIN)
  expect(await band($, /Slow 1m/)).toBeUndefined()
  expect(toasts.join(' ')).toMatch(/1 failed · .* 1 done/)
  expect(written.alerts).toEqual([{ source: 'agent:a2', kind: 'agent', text: 'Broken failed' }])
})
