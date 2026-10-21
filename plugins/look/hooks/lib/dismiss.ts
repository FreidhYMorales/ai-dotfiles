// Dismissals are `$.store` keys `look:dismiss:<source key>` = { at }.
export const PREFIX = 'look:dismiss:'
export const MAX_AGE_MS = 30 * 24 * 60 * 60_000

export const dismissKey = (source: string): string => PREFIX + source

/**
 * Splits store keys into live source keys and stale store keys to delete.
 * Keys outside the prefix are ignored; an entry without a valid `at` is stale.
 */
export function splitDismissals(entries: { key: string; at: number | undefined }[], now: number): { live: string[]; stale: string[] } {
  const live: string[] = []
  const stale: string[] = []
  for (const { key, at } of entries) {
    if (!key.startsWith(PREFIX)) continue
    if (typeof at === 'number' && now - at <= MAX_AGE_MS) live.push(key.slice(PREFIX.length))
    else stale.push(key)
  }

  return { live, stale }
}
