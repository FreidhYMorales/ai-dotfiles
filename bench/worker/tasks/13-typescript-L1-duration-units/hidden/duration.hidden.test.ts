// Hidden test for 13-typescript-L1-duration-units (cwd = repo root).
import { test } from "node:test";
import assert from "node:assert/strict";
import { pathToFileURL } from "node:url";

const mod = await import(pathToFileURL(`${process.cwd()}/src/duration.ts`).href);
const { parseDuration, formatDuration } = mod as {
  parseDuration: (s: string) => number;
  formatDuration: (n: number) => string;
};

test("days", () => {
  assert.equal(parseDuration("1d"), 86_400_000);
  assert.equal(parseDuration("2d"), 172_800_000);
  assert.equal(parseDuration("1d12h"), 129_600_000);
});

test("milliseconds", () => {
  assert.equal(parseDuration("250ms"), 250);
  assert.equal(parseDuration("5ms"), 5);
  assert.equal(parseDuration("1m30s500ms"), 90_500);
  assert.equal(parseDuration("1s1ms"), 1_001);
  assert.equal(parseDuration("1d1h1m1s1ms"), 90_061_001);
});

test("old units unchanged", () => {
  assert.equal(parseDuration("5m"), 300_000);
  assert.equal(parseDuration("45s"), 45_000);
  assert.equal(parseDuration("1h30m"), 5_400_000);
  assert.equal(parseDuration("5m5s"), 305_000);
});

test("still rejects garbage", () => {
  for (const bad of ["", "ms", "d", "5", "5x", "5md", "5msx", "1.5h", "1d 2h", "-1ms", "5mss"]) {
    assert.throws(() => parseDuration(bad), Error, `should reject ${JSON.stringify(bad)}`);
  }
});

test("formatDuration unchanged", () => {
  assert.equal(formatDuration(5_400_000), "1h30m");
  assert.equal(formatDuration(1_500), "1s");
  assert.equal(formatDuration(90_000_000), "25h");
});
