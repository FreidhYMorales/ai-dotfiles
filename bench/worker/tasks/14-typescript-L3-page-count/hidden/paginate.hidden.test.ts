// Hidden test for 14-typescript-L3-page-count (cwd = repo root).
import { test } from "node:test";
import assert from "node:assert/strict";
import { pathToFileURL } from "node:url";

const load = (f: string) => import(pathToFileURL(`${process.cwd()}/src/${f}`).href);
const { paginate, pageCount } = await load("paginate.ts");
const { pageLinks } = await load("links.ts");
const range = (n: number) => Array.from({ length: n }, (_, i) => i + 1);

test("exact multiple has no extra page", () => {
  const p = paginate(range(20), 2, 10);
  assert.equal(p.pageCount, 2);
  assert.equal(p.hasNext, false);
  assert.deepEqual(p.items, range(20).slice(10));
  assert.equal(paginate(range(30), 1, 10).pageCount, 3);
  assert.equal(paginate(range(10), 1, 10).pageCount, 1);
  assert.equal(paginate(range(10), 1, 10).hasNext, false);
});

test("pages past the end clamp to the real last page", () => {
  const p = paginate(range(20), 3, 10);
  assert.equal(p.page, 2);
  assert.deepEqual(p.items, range(20).slice(10));
});

test("pageCount", () => {
  assert.equal(pageCount(0, 10), 1);
  assert.equal(pageCount(1, 10), 1);
  assert.equal(pageCount(9, 10), 1);
  assert.equal(pageCount(10, 10), 1);
  assert.equal(pageCount(11, 10), 2);
  assert.equal(pageCount(20, 10), 2);
  assert.equal(pageCount(21, 10), 3);
  assert.equal(pageCount(7, 1), 7);
});

test("unchanged behavior", () => {
  const p = paginate(range(25), 3, 10);
  assert.deepEqual(p.items, [21, 22, 23, 24, 25]);
  assert.equal(p.pageCount, 3);
  const e = paginate([], 5, 10);
  assert.deepEqual(e.items, []);
  assert.equal(e.page, 1);
  assert.equal(e.pageCount, 1);
  assert.equal(e.hasNext, false);
  assert.equal(e.total, 0);
});

test("page links follow the page count", () => {
  assert.deepEqual(pageLinks(20, 10, 1), [1, 2]);
  assert.deepEqual(pageLinks(100, 10, 5), [1, null, 4, 5, 6, null, 10]);
  assert.deepEqual(pageLinks(0, 10, 1), [1]);
});
