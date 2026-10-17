#!/usr/bin/env bash
# Hidden check: slugify(max_length=...) cuts at word boundaries.
set -u
exec python3 "$(dirname "${BASH_SOURCE[0]}")/hidden/check.py"
