import { mock } from 'claude-code/testing'
import type { Engine, On } from 'claude-code'

// Nothing draws beneath the plugin: the hooks here stand for the engine.
export function world(on: On) {
  const toasts: string[] = []
  // What the plugin wrote to its atoms: the host's copy, seen from outside.
  const written: Record<string, unknown> = {}
  const writes: string[] = []
  let seq = 0
  const agents: { id: string; status: string }[] = []
  const clock = mock.clock(on, { now: 1_000_000 })
  const spawnReply: { deny?: string } = {}
  on('agent.spawn', () => (spawnReply.deny ? ({ deny: spawnReply.deny } as never) : { model: 'm', agentId: `a${(seq += 1)}` }))
  on('agent.list', () => ({ value: agents as never }))
  // No HOME by default, so the backup poll finds nothing configured and never reads the real disk.
  const vars: Record<string, string> = {}
  on('env.get', (_, e) => ({ value: vars[e.name] }))
  on('command.register', () => ({ value: { command: 'band' } }))
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

  return { toasts, clock, written, writes, agents, spawnReply, vars }
}

let n = 0
export const bg = ($: Engine, command: string, description?: string) =>
  $.tool.call({ tool: 'Bash', command, description, run_in_background: true })
export const begin = ($: Engine) => $.session.start({ cwd: '/', surface: 'terminal', isInteractive: true })

export async function note($: Engine, clock: { settle: () => Promise<void> }, id: string, status: string, toolUseId = 'tu') {
  const task = { id, status, toolUseId }
  const props = { text: '', origin: { kind: 'task-notification' }, isExpanded: false, task }
  const ui = await $.ui.mount({ plugin: 'look', component: 'UserMessage', requestId: `n${(n += 1)}`, surface: 'terminal', props } as never)
  await clock.settle()
  await ui.unmount()
}

export function mountBand($: Engine) {
  const props = { hasSurvey: false, isWorking: false, maxRows: 6, bodyColumns: 80, scroll: { offset: 0, bodyRows: 6 }, view: {} }

  return $.ui.mount({ plugin: 'look', component: 'AbovePrompt', requestId: `b${(n += 1)}`, surface: 'terminal', props } as never)
}

export async function band($: Engine, re: RegExp) {
  const ui = await mountBand($)
  const found = (await ui.find({ type: 'Text', text: re }))?.text
  await ui.unmount()

  return found
}

// The shared `$.store`, in memory: the test reads and writes the Map as the
// other session would.
export function memStore(on: On, entries: Record<string, unknown> = {}) {
  const map = new Map<string, unknown>(Object.entries(entries))
  on('store.get', (_, e) => ({ value: map.get(e.key) }) as never)
  on('store.set', (_, e) => {
    map.set(e.key, e.value)

    return { value: undefined } as never
  })
  on('store.delete', (_, e) => {
    map.delete(e.key)

    return { value: undefined } as never
  })
  on('store.keys', () => ({ value: [...map.keys()] }) as never)

  return map
}
