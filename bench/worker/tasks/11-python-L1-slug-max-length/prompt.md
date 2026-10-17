Add a `max_length` keyword argument to `slugify` in `slugkit/slug.py`
(default `None`: no limit, same result as today). With a limit, the slug is at
most `max_length` characters long:

- it is cut at a separator so no word is split: drop whole words from the end
  until it fits, and never leave a trailing separator
- only when the first word alone is longer than `max_length` is that word cut
  to exactly `max_length` characters
- `max_length` must be a positive integer; `0` or a negative value raises
  `ValueError`

Add tests for it to `tests/test_slug.py`, then run `python3 -m unittest` and
make sure every test passes. Change only those two files.
