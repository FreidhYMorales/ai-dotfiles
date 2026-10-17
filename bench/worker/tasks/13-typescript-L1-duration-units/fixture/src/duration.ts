// Human durations such as "1h30m" or "45s", as milliseconds.

const UNIT_MS: Record<string, number> = {
  h: 3_600_000,
  m: 60_000,
  s: 1_000,
};

const PART = /(\d+)([hms])/g;
const WHOLE = /^(?:\d+[hms])+$/;

/** Parse "1h30m", "90s", "2h" into milliseconds. Throws on anything else. */
export function parseDuration(input: string): number {
  const text = input.trim();
  if (!WHOLE.test(text)) {
    throw new Error(`invalid duration: ${JSON.stringify(input)}`);
  }
  let total = 0;
  for (const [, amount, unit] of text.matchAll(PART)) {
    total += Number(amount) * UNIT_MS[unit];
  }
  return total;
}

/** Format milliseconds as the shortest "1h30m"-style string ("0s" for 0). */
export function formatDuration(ms: number): string {
  if (!Number.isFinite(ms) || ms < 0) {
    throw new Error(`invalid milliseconds: ${ms}`);
  }
  let rest = Math.floor(ms / 1000) * 1000;
  let out = "";
  for (const [unit, size] of Object.entries(UNIT_MS)) {
    const n = Math.floor(rest / size);
    if (n > 0) {
      out += `${n}${unit}`;
      rest -= n * size;
    }
  }
  return out || "0s";
}
