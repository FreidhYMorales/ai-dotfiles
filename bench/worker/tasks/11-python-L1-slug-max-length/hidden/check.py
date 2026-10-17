"""Hidden check for 11-python-L1-slug-max-length (cwd = repo root)."""

import os
import sys
import unittest

sys.path.insert(0, os.getcwd())
from slugkit import slugify  # noqa: E402


class Hidden(unittest.TestCase):
    def test_no_limit_unchanged(self):
        self.assertEqual(slugify("Hello World Again"), "hello-world-again")
        self.assertEqual(slugify("Hello World Again", max_length=None), "hello-world-again")
        self.assertEqual(slugify("Hello World Again", max_length=100), "hello-world-again")

    def test_exact_fit(self):
        self.assertEqual(slugify("Hello World Again", max_length=17), "hello-world-again")

    def test_drops_whole_words(self):
        self.assertEqual(slugify("Hello World Again", max_length=16), "hello-world")
        self.assertEqual(slugify("Hello World Again", max_length=12), "hello-world")
        self.assertEqual(slugify("Hello World Again", max_length=11), "hello-world")
        self.assertEqual(slugify("Hello World Again", max_length=10), "hello")

    def test_first_word_too_long_is_cut(self):
        self.assertEqual(slugify("Hello World", max_length=5), "hello")
        self.assertEqual(slugify("Hello World", max_length=4), "hell")
        self.assertEqual(slugify("Supercalifragilistic", max_length=1), "s")

    def test_custom_separator_counts(self):
        self.assertEqual(slugify("a bb ccc", sep="__", max_length=7), "a__bb")
        self.assertEqual(slugify("a bb ccc", sep="__", max_length=12), "a__bb__ccc")
        self.assertEqual(slugify("a bb ccc", sep="__", max_length=6), "a__bb")
        self.assertEqual(slugify("a bb ccc", sep="__", max_length=4), "a")

    def test_accents_then_limit(self):
        self.assertEqual(slugify("Café Crème Brûlée", max_length=11), "cafe-creme")

    def test_empty_stays_empty(self):
        self.assertEqual(slugify("!!!", max_length=3), "")

    def test_invalid_limit(self):
        for bad in (0, -1):
            with self.assertRaises(ValueError):
                slugify("Hello", max_length=bad)


if __name__ == "__main__":
    result = unittest.main(exit=False, verbosity=1).result
    sys.exit(0 if result.wasSuccessful() else 1)
