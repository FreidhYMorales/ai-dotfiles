import { truncate } from './layout'

const WORDS = 3
const VAR_PREFIX = /^[A-Za-z_][A-Za-z0-9_]*=\S*$/

/** Drops leading `cd … &&` segments, as in `cd "/my dir" && make check`. */
function stripCd(cmd: string): string {
  let rest = cmd.trim()
  for (;;) {
    const m = /^cd\s+(?:"[^"]*"|'[^']*'|\S+)\s*&&\s*/.exec(rest)
    if (!m) return rest
    rest = rest.slice(m[0].length)
  }
}

/**
 * Key and fallback label of a shell command: no leading `cd … &&` or `VAR=`
 * prefixes, the first three words, and the value of any `=value` masked as
 * `=*` (it may hold a secret). The command is only parsed, never run.
 */
export function normalizeCommand(cmd: string): string {
  const words = stripCd(cmd).split(/\s+/).filter(Boolean)
  while (words.length > 1 && VAR_PREFIX.test(words[0]!)) words.shift()
  return words
    .slice(0, WORDS)
    .map(w => w.replace(/=.+$/s, '=*'))
    .join(' ')
}

/** The Bash description (truncated), else the normalized command. */
export function shellLabel(description: string | undefined, key: string, max: number): string {
  const d = description?.trim()
  return truncate(d ? d : key, max)
}
