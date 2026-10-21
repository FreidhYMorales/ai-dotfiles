import type { EngineInterface } from 'claude-code'
import { atom, read } from 'claude-code'

import { buildBand } from '../lib/layout'
import { logOnce } from './timers'

// The validator reads atoms only where they are declared in the same file, so
// each file declares the few it uses (same keys, same initials).
const running = atom({ plugin: 'look', key: 'running' } as const, {})
const shellFails = atom({ plugin: 'look', key: 'shellFails' } as const, {})
const alerts = atom({ plugin: 'look', key: 'alerts' } as const, [])
const dismissed = atom({ plugin: 'look', key: 'dismissed' } as const, [])
const now = atom({ plugin: 'look', key: 'now' } as const, 0)

/** The band: read-only, and `next(e)` whenever there is nothing to draw. */
export async function renderBand($: EngineInterface, e: any, next: (e: any) => any): Promise<unknown> {
  try {
    if (e.props.hasSurvey) return next(e)
    const state = {
      running: await read($, running),
      shellFails: await read($, shellFails),
      alerts: await read($, alerts),
      dismissed: await read($, dismissed),
    }
    const rows = buildBand(state, e.props.maxRows, e.props.bodyColumns, await read($, now))
    if (rows.length === 0) return next(e)
    const { Box, Text } = $.ui.resolve(e)

    return (
      <Box flexDirection="column">
        {rows.map(r => (
          <Text color={r.kind === 'alert' ? 'red' : undefined} dimColor={r.kind !== 'alert' && r.kind !== 'activity'}>
            {r.text}
          </Text>
        ))}
      </Box>
    )
  } catch (err) {
    logOnce($, 'render', err)

    return next(e)
  }
}
