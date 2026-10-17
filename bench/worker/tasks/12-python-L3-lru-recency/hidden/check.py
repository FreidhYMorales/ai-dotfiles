"""Hidden check for 12-python-L3-lru-recency (cwd = repo root)."""

import os
import sys
import unittest

sys.path.insert(0, os.getcwd())
from lru import LRUCache  # noqa: E402


def filled(*keys, capacity=None):
    c = LRUCache(capacity or len(keys))
    for i, k in enumerate(keys):
        c.put(k, i)
    return c


class Hidden(unittest.TestCase):
    def test_get_refreshes(self):
        c = filled("a", "b")
        self.assertEqual(c.get("a"), 0)
        c.put("c", 2)
        self.assertIn("a", c)
        self.assertNotIn("b", c)

    def test_get_order(self):
        c = filled("a", "b", "c")
        c.get("a")
        c.get("b")
        self.assertEqual(c.keys(), ["c", "a", "b"])

    def test_miss_does_not_change_order(self):
        c = filled("a", "b")
        c.get("zz")
        self.assertEqual(c.keys(), ["a", "b"])

    def test_peek_does_not_refresh(self):
        c = filled("a", "b")
        self.assertEqual(c.peek("a"), 0)
        c.put("c", 2)
        self.assertNotIn("a", c)
        self.assertEqual((c.hits, c.misses), (0, 0))

    def test_contains_does_not_refresh(self):
        c = filled("a", "b")
        self.assertIn("a", c)
        c.put("c", 2)
        self.assertNotIn("a", c)

    def test_put_refreshes(self):
        c = filled("a", "b")
        c.put("a", 9)
        c.put("c", 2)
        self.assertEqual(c.keys(), ["a", "c"])
        self.assertEqual(c.peek("a"), 9)

    def test_stats(self):
        c = filled("a", "b")
        c.get("a")
        c.get("a")
        c.get("x")
        self.assertEqual((c.hits, c.misses), (2, 1))

    def test_falsy_values_are_hits(self):
        c = LRUCache(2)
        c.put("none", None)
        c.put("zero", 0)
        self.assertIsNone(c.get("none", "default"))
        self.assertEqual(c.get("zero", 5), 0)
        self.assertEqual((c.hits, c.misses), (2, 0))
        self.assertEqual(c.keys(), ["none", "zero"])


if __name__ == "__main__":
    result = unittest.main(exit=False, verbosity=1).result
    sys.exit(0 if result.wasSuccessful() else 1)
