import unittest

from slugkit import slugify


class SlugifyTest(unittest.TestCase):
    def test_basic(self):
        self.assertEqual(slugify("Hello World"), "hello-world")

    def test_accents_and_punctuation(self):
        self.assertEqual(slugify("Héllo, Wörld!"), "hello-world")

    def test_collapses_runs(self):
        self.assertEqual(slugify("  a -- b  "), "a-b")

    def test_custom_separator(self):
        self.assertEqual(slugify("Hello World", sep="_"), "hello_world")

    def test_empty(self):
        self.assertEqual(slugify("!!!"), "")

    def test_rejects_non_str(self):
        with self.assertRaises(TypeError):
            slugify(42)


if __name__ == "__main__":
    unittest.main()
