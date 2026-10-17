# lru

A small in-memory LRU cache used in front of a slow lookup service.

    from lru import LRUCache
    cache = LRUCache(capacity=1000)
    cache.put("user:1", {...})
    cache.get("user:1")

Run the tests with `python3 -m unittest`.
