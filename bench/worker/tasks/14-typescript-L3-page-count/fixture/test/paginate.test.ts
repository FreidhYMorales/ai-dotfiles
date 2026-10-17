import { test } from "node:test";
import assert from "node:assert/strict";
import { paginate } from "../src/paginate.ts";
import { pageLinks } from "../src/links.ts";

const items = Array.from({ length: 25 }, (_, i) => i + 1);

test("first page", () => {
  const p = paginate(items, 1, 10);
  assert.deepEqual(p.items, [1, 2, 3, 4, 5, 6, 7, 8, 9, 10]);
  assert.equal(p.pageCount, 3);
  assert.equal(p.hasPrev, false);
  assert.equal(p.hasNext, true);
});

test("last partial page", () => {
  const p = paginate(items, 3, 10);
  assert.deepEqual(p.items, [21, 22, 23, 24, 25]);
  assert.equal(p.hasNext, false);
});

test("clamps out-of-range pages", () => {
  assert.equal(paginate(items, 0, 10).page, 1);
  assert.equal(paginate(items, 99, 10).page, 3);
});

test("empty list has one empty page", () => {
  const p = paginate([], 1, 10);
  assert.deepEqual(p.items, []);
  assert.equal(p.pageCount, 1);
});

test("rejects a bad perPage", () => {
  assert.throws(() => paginate(items, 1, 0), RangeError);
});

test("page links with gaps", () => {
  assert.deepEqual(pageLinks(95, 10, 5), [1, null, 4, 5, 6, null, 10]);
});
