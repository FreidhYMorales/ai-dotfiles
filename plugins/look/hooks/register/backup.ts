import type { EngineInterface } from 'claude-code'
import { atom, update } from 'claude-code'

import { backupRules, configPath, stateDir } from '../lib/backup'
import { logOnce } from './timers'

// The validator reads atoms only where they are declared in the same file, so
// each file declares the few it uses (same keys, same initials).
const alerts = atom({ plugin: 'look', key: 'alerts' } as const, [])

const POLL_MS = 5 * 60_000
// Only a handle: a reload drops it with the old timers; the next session.start starts one again.
let pollHandle: { cancel: () => void } | null = null

/** Starts the 5 min poll once and polls at once. */
export function startBackupPoll($: EngineInterface): void {
  pollHandle ??= $.clock.every(POLL_MS, () => {
    void pollBackup($)
  })
  void pollBackup($)
}

/** Reads the state files and makes the backup alerts match; a read error is logged once. */
export async function pollBackup($: EngineInterface): Promise<void> {
  try {
    const env = { HOME: await $.env.get('HOME'), XDG_STATE_HOME: await $.env.get('XDG_STATE_HOME'), XDG_CONFIG_HOME: await $.env.get('XDG_CONFIG_HOME') }
    const dir = stateDir(env)
    const config = configPath(env)
    const configured = !!config && (await $.fs.exists(config))
    // An unreadable file is read as broken, which the rules report as failed.
    const file = async (name: string): Promise<string | undefined> => {
      const path = `${dir}/${name}.json`
      if (!(await $.fs.exists(path))) return undefined
      try {
        return await $.fs.read(path)
      } catch (err) {
        logOnce($, 'backup', err)

        return ''
      }
    }
    const found = configured && dir ? backupRules({ now: await $.clock.now(), configured, backup: await file('backup'), verify: await file('verify'), scan: await file('scan') }) : []
    await update($, alerts, a => {
      const others = a.filter(x => x.kind !== 'backup')
      const same = JSON.stringify(a.filter(x => x.kind === 'backup')) === JSON.stringify(found)

      return same ? a : [...others, ...found]
    })
  } catch (err) {
    logOnce($, 'backup', err)
  }
}
