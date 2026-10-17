Bug report for the `lru` package (see README.md):

In production our hottest keys keep missing: a key that is read on almost
every request gets evicted from the cache shortly after it was read, while
keys that nobody has read for a long time stay cached. The hit rate is far
below what the cache size should give.

Find the cause and fix it, keeping the documented behavior of every method.
Add a test that reproduces the problem to `tests/test_cache.py`, then run
`python3 -m unittest` and make sure every test passes. Change only
`lru/cache.py` and `tests/test_cache.py`.
