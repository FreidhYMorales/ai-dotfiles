import { test } from "node:test";
import assert from "node:assert/strict";
import { loadLibrary, plain } from "./pragma.mjs";

const { buildWorkspaces, nextWorkspace, workspaceLabel } = loadLibrary("../utils/workspaces.js");

test("lists 1..shown even when empty", () => {
  assert.deepStrictEqual(plain(buildWorkspaces([], 1, 3)), [
    { id: 1, active: true, occupied: false },
    { id: 2, active: false, occupied: false },
    { id: 3, active: false, occupied: false },
  ]);
});

test("marks occupied workspaces", () => {
  const ws = buildWorkspaces([{ id: 2, windows: 3 }, { id: 3, windows: 0 }], 1, 3);
  assert.deepStrictEqual(plain(ws).map((w) => w.occupied), [false, true, false]);
});

test("adds existing workspaces beyond shown", () => {
  const ws = buildWorkspaces([{ id: 7, windows: 1 }], 1, 5);
  assert.deepStrictEqual(plain(ws).map((w) => w.id), [1, 2, 3, 4, 5, 7]);
});

test("skips special workspaces", () => {
  const ws = buildWorkspaces([{ id: -98, windows: 2 }], 1, 2);
  assert.deepStrictEqual(plain(ws).map((w) => w.id), [1, 2]);
});

test("scroll moves to the neighbour and wraps", () => {
  const ws = buildWorkspaces([], 1, 5);
  assert.equal(nextWorkspace(ws, 2, 1), 3);
  assert.equal(nextWorkspace(ws, 2, -1), 1);
  assert.equal(nextWorkspace(ws, 5, 1), 1);
  assert.equal(nextWorkspace(ws, 1, -1), 5);
});

test("labels use roman numerals up to X", () => {
  assert.equal(workspaceLabel(4), "IV");
  assert.equal(workspaceLabel(12), "12");
});
