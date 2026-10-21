import type { LookItem } from '../../types/index'
import { G } from './glyphs'

// Mirrors PluginState['look'] without importing the ambient module, so this
// file stays pure and loadable from tests.
type Look = {
  running: Record<string, LookItem>
  shellFails: Record<string, { key: string; label: string; at: number }>
  alerts: { source: string; kind: 'ci' | 'agent' | 'backup'; text: string }[]
  dismissed: string[]
}

export type BandRow = {
  kind: 'alert' | 'fail' | 'activity' | 'more'
  text: string
  /** Dismissal source key, alerts only. */
  source?: string
  /** 1..9, alerts only. */
  hotkey?: number
}

const RESERVED = 2
const ALERT_BUTTON = 6 // " [1 ✕]" drawn next to an alert
const SEP = ' · '

/**
 * Width assumption: every code point is one column. Nerd Font glyphs (PUA)
 * are one column in the target font; wide CJK or emoji are not measured.
 */
export function truncate(text: string, max: number): string {
  const cps = Array.from(text)
  if (cps.length <= max) return text
  if (max <= 0) return ''
  return cps.slice(0, max - 1).join('') + '…'
}

export function formatElapsed(ms: number): string {
  const s = Math.max(0, Math.floor(ms / 1000))
  if (s < 60) return `${s}s`
  const m = Math.floor(s / 60)
  const pad = (n: number): string => String(n).padStart(2, '0')
  if (m < 60) return `${m}m${pad(s % 60)}s`
  return `${Math.floor(m / 60)}h${pad(m % 60)}m`
}

const KIND_GLYPH = { ci: G.ci, agent: G.agent, shell: G.shell } as const

function hhmm(at: number): string {
  const d = new Date(at)
  const pad = (n: number): string => String(n).padStart(2, '0')
  return `${pad(d.getHours())}:${pad(d.getMinutes())}`
}

/**
 * Pure rows of the band: alerts, shell-failure rows, then activity (one line
 * for 3 or fewer items, one row each above that). Everything beyond `maxRows`
 * folds into a `+N more` row. Nothing is right-aligned.
 */
export function buildBand(state: Look, maxRows: number, bodyColumns: number, now: number): BandRow[] {
  const width = Math.max(0, bodyColumns - RESERVED)
  // n = how many things a row stands for, used by the `+N more` count.
  const out: { row: BandRow; n: number }[] = []

  let hotkey = 0
  for (const a of state.alerts) {
    if (state.dismissed.includes(a.source)) continue
    hotkey += 1
    out.push({
      row: {
        kind: 'alert',
        text: truncate(`${G.fail} ${a.text}`, width - ALERT_BUTTON),
        source: a.source,
        ...(hotkey <= 9 ? { hotkey } : {}),
      },
      n: 1,
    })
  }

  for (const f of Object.values(state.shellFails)) {
    out.push({ row: { kind: 'fail', text: truncate(`${G.dim} ${f.label} failed ${hhmm(f.at)}`, width) }, n: 1 })
  }

  const items = Object.values(state.running).sort((a, b) => a.startedAt - b.startedAt)
  const texts = items.map(i => `${KIND_GLYPH[i.kind]} ${i.label} ${formatElapsed(now - i.startedAt)}`)
  if (items.length > 0 && items.length <= 3) {
    out.push({ row: { kind: 'activity', text: truncate(texts.join(SEP), width) }, n: items.length })
  } else {
    for (const t of texts) out.push({ row: { kind: 'activity', text: truncate(t, width) }, n: 1 })
  }

  if (maxRows < 1) return []
  if (out.length <= maxRows) return out.map(o => o.row)
  const kept = out.slice(0, maxRows - 1)
  const more = out.slice(maxRows - 1).reduce((sum, o) => sum + o.n, 0)
  return [...kept.map(o => o.row), { kind: 'more', text: `+${more} more` }]
}
