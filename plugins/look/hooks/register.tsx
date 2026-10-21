import type { Register } from 'claude-code'

import { renderBand } from './register/band'
import { onBash, onNotification } from './register/ingest'
import { syncTick } from './register/timers'

// Hooks only record events and schedule work (see register/): the render hook
// reads atoms and draws. Timers start from session.start and are idempotent.
export const register: Register = on => {
  on('session.start', async ($, e, next) => {
    await syncTick($)

    return next(e)
  })

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
