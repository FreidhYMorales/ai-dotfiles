// Frozen state contract of the look band. Slices fill these atoms; none
// renames a field. Keys of `$.store`:
//   look:dismiss:ci:<root>:<branch>:<pr>:<sha>, look:dismiss:backup:<rule>:<time>,
//   look:dismiss:agent:<id>  each { at }, pruned after 30 days
//   look:ci:<root>:<branch>  { at, pr, headSha, checks }, shared by sessions

export type LookItem = {
  id: string
  toolUseId?: string
  kind: 'ci' | 'agent' | 'shell'
  label: string
  /** Normalized command, for shells. */
  key?: string
  startedAt: number
}

export type LookAlert = {
  /** Dismissal source key. */
  source: string
  kind: 'ci' | 'agent' | 'backup'
  text: string
}

export type LookShellFail = { key: string; label: string; at: number }

export type LookCi = {
  root: string
  branch: string
  pr: number
  headSha: string
  state: 'pending' | 'ok' | 'failed'
  failing: string[]
}

declare module 'claude-code' {
  interface PluginState {
    look: {
      running: Record<string, LookItem>
      shellFails: Record<string, LookShellFail>
      alerts: LookAlert[]
      ci: LookCi | null
      dismissed: string[]
      now: number
    }
  }
}
