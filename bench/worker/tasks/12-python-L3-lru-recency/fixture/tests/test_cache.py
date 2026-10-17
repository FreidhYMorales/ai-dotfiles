import unittest

from lru import LRUCache


class LRUCacheTest(unittest.TestCase):
    def test_get_and_put(self):
        c = LRUCache(2)
        c.put("a", 1)
        self.assertEqual(c.get("a"), 1)
        self.assertIsNone(c.get("zz"))
        self.assertEqual(c.get("zz", 0), 0)

    def test_evicts_oldest_insert(self):
        c = LRUCache(2)
        c.put("a", 1)
        c.put("b", 2)
        c.put("c", 3)
        self.assertNotIn("a", c)
        self.assertEqual(len(c), 2)

    def test_put_existing_updates_without_growing(self):
        c = LRUCache(2)
        c.put("a", 1)
        c.put("a", 2)
        self.assertEqual(c.get("a"), 2)
        self.assertEqual(len(c), 1)

    def test_stats(self):
        c = LRUCache(2)
        c.put("a", 1)
        c.get("a")
        c.get("b")
        self.assertEqual((c.hits, c.misses), (1, 1))

    def test_pop(self):
        c = LRUCache(2)
        c.put("a", 1)
        self.assertEqual(c.pop("a"), 1)
        self.assertNotIn("a", c)

    def test_capacity_must_be_positive(self):
        with self.assertRaises(ValueError):
            LRUCache(0)


if __name__ == "__main__":
    unittest.main()
