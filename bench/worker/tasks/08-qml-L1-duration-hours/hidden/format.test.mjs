// Hidden test for utils/format.js (path in $LIB).
import { test } from "node:test";
import assert from "node:assert/strict";

const { loadLibrary } = await import(`${process.env.QML_SHARED}/pragma.mjs`);
const { formatDuration } = loadLibrary(process.env.LIB);

test("formatDuration is defined", () => {
  assert.equal(typeof formatDuration, "function");
});

test("under one hour keeps m:ss", () => {
  assert.equal(formatDuration(0), "0:00");
  assert.equal(formatDuration(5), "0:05");
  assert.equal(formatDuration(65), "1:05");
  assert.equal(formatDuration(599.9), "9:59");
  assert.equal(formatDuration(3599), "59:59");
});

test("one hour or more is h:mm:ss", () => {
  assert.equal(formatDuration(3600), "1:00:00");
  assert.equal(formatDuration(3725), "1:02:05");
  assert.equal(formatDuration(4500), "1:15:00");
  assert.equal(formatDuration(36061), "10:01:01");
  assert.equal(formatDuration(3600.7), "1:00:00");
});

test("bad input gives 0:00", () => {
  assert.equal(formatDuration(-5), "0:00");
  assert.equal(formatDuration(NaN), "0:00");
  assert.equal(formatDuration(undefined), "0:00");
});
