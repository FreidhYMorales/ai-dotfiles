#!/usr/bin/env bash
# Hidden check: get() refreshes recency; peek()/in/pop do not; stats intact.
set -u
exec python3 "$(dirname "${BASH_SOURCE[0]}")/hidden/check.py"
