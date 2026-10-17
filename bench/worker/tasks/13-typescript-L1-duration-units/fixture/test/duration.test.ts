import { test } from "node:test";
import assert from "node:assert/strict";
import { formatDuration, parseDuration } from "../src/duration.ts";

test("parses single units", () => {
  assert.equal(parseDuration("2h"), 7_200_000);
  assert.equal(parseDuration("5m"), 300_000);
  assert.equal(parseDuration("45s"), 45_000);
});

test("parses combinations", () => {
  assert.equal(parseDuration("1h30m"), 5_400_000);
  assert.equal(parseDuration(" 1m30s "), 90_000);
});

test("rejects garbage", () => {
  for (const bad of ["", "5", "h", "5x", "1h 30m", "-1s"]) {
    assert.throws(() => parseDuration(bad), /invalid duration/);
  }
});

test("formats durations", () => {
  assert.equal(formatDuration(0), "0s");
  assert.equal(formatDuration(5_400_000), "1h30m");
  assert.equal(formatDuration(61_000), "1m1s");
});
