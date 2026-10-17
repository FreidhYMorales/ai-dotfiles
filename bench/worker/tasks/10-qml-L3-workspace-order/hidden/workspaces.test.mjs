// Hidden test for the fixture's utils/workspaces.js (path in $LIB).
import { test } from "node:test";
import assert from "node:assert/strict";

const { loadLibrary } = await import(`${process.env.QML_SHARED}/pragma.mjs`);
const { buildWorkspaces, nextWorkspace, workspaceLabel } = loadLibrary(process.env.LIB);
const plain = (v) => JSON.parse(JSON.stringify(v));
const ids = (ws) => plain(ws).map((w) => w.id);

test("10 shown workspaces are in numeric order", () => {
  assert.deepStrictEqual(ids(buildWorkspaces([], 1, 10)), [1, 2, 3, 4, 5, 6, 7, 8, 9, 10]);
});

test("extra workspaces 10+ go after 9, sorted numerically", () => {
  const ws = buildWorkspaces([{ id: 21, windows: 1 }, { id: 12, windows: 2 }, { id: -98, windows: 1 }, { id: 3, windows: 1 }], 1, 5);
  assert.deepStrictEqual(ids(ws), [1, 2, 3, 4, 5, 12, 21]);
  assert.deepStrictEqual(plain(ws).map((w) => w.occupied), [false, false, true, false, false, true, true]);
});

test("an empty active workspace beyond shown is listed in order", () => {
  const ws = buildWorkspaces([{ id: 100, windows: 1 }], 11, 3);
  assert.deepStrictEqual(ids(ws), [1, 2, 3, 11, 100]);
  assert.deepStrictEqual(plain(ws).map((w) => w.active), [false, false, false, true, false]);
});

test("scrolling follows numeric order", () => {
  const ws = buildWorkspaces([], 1, 10);
  assert.equal(nextWorkspace(ws, 1, 1), 2);
  assert.equal(nextWorkspace(ws, 9, 1), 10);
  assert.equal(nextWorkspace(ws, 10, 1), 1);
  assert.equal(nextWorkspace(ws, 1, -1), 10);
  assert.equal(nextWorkspace(ws, 2, -1), 1);
});

test("unchanged behavior", () => {
  assert.deepStrictEqual(ids(buildWorkspaces([{ id: 7, windows: 1 }], 1, 5)), [1, 2, 3, 4, 5, 7]);
  assert.deepStrictEqual(plain(buildWorkspaces([], 2, 2)), [
    { id: 1, active: false, occupied: false },
    { id: 2, active: true, occupied: false },
  ]);
  assert.equal(nextWorkspace([], 4, 1), 4);
  assert.equal(workspaceLabel(10), "X");
});
