"""Least-recently-used cache."""

from collections import OrderedDict

_MISSING = object()


class LRUCache:
    """Keep at most `capacity` entries; when full, adding a new key evicts the
    least recently used entry. Both get() and put() count as a use; peek()
    and `in` do not.
    """

    def __init__(self, capacity):
        if capacity < 1:
            raise ValueError("capacity must be at least 1")
        self.capacity = capacity
        self.hits = 0
        self.misses = 0
        self._data = OrderedDict()

    def get(self, key, default=None):
        """Return the value for key (counting a hit), or default (a miss)."""
        value = self._data.get(key, _MISSING)
        if value is _MISSING:
            self.misses += 1
            return default
        self.hits += 1
        return value

    def peek(self, key, default=None):
        """Return the value for key without touching recency or stats."""
        return self._data.get(key, default)

    def put(self, key, value):
        """Insert or replace key, evicting the least recently used entry."""
        if key in self._data:
            self._data.move_to_end(key)
        self._data[key] = value
        while len(self._data) > self.capacity:
            self._data.popitem(last=False)

    def pop(self, key, default=None):
        """Remove key and return its value, or default."""
        return self._data.pop(key, default)

    def keys(self):
        """Keys from least to most recently used."""
        return list(self._data)

    def __contains__(self, key):
        return key in self._data

    def __len__(self):
        return len(self._data)
