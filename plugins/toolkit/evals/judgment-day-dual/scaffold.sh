#!/usr/bin/env bash
# One small Python file with an off-by-one bug for the judges to find.
set -eu
mkdir -p src
cat >src/paginate.py <<'PY'
def page(items, number, size):
    """Return page `number` (1-based) of `items`, `size` items per page."""
    start = number * size
    return items[start:start + size]


def page_count(items, size):
    return len(items) // size
PY
