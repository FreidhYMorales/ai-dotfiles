import type { Register } from 'claude-code'

import { renderBand } from './register/band'
import { clearBand, startDismissTick } from './register/dismiss'
import { onAgent, onBash, onNotification, syncAgents } from './register/ingest'
import { syncTick } from './register/timers'

// Hooks only record events and schedule work (see register/): the render hook
// reads atoms and draws. Timers start from session.start and are idempotent.
export const register: Register = on => {
  on('session.start', async ($, e, next) => {
    await syncTick($)
    await syncAgents($)
    await startDismissTick($)
    await $.command.register({ name: 'band', description: 'Dismiss every alert and clear the band', argumentHint: 'clear' })

    return next(e)
  })

  on('command.run', { command: 'band' }, async ($, e) => {
    if (e.args.trim() !== 'clear') return { text: 'Usage: /band clear' }
    await clearBand($)

    return { text: 'Band cleared.' }
  })

  on('agent.spawn', ($, e, next) => onAgent($, e, next))

  on('tool.call', async ($, e, next) => {
    const out = await next(e)
    await onBash($, e, out)

    return out
  })

  on('ui.render', { component: 'UserMessage', props: { origin: { kind: 'task-notification' } } }, async ($, e, next) => {
    await onNotification($, e.props.task)

    return next(e)
  })

  on('ui.render', { component: 'AbovePrompt' }, ($, e, next) => renderBand($, e, next))
}
