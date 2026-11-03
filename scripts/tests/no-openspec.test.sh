#!/usr/bin/env bash
# Structural test for the retired openspec/ tree: it is gone, and only history
# still names it.
# Run: bash scripts/tests/no-openspec.test.sh
set -u

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
failures=0

assert() {
  local label=$1
  shift
  if "$@"; then
    printf 'PASS  %s\n' "$label"
  else
    printf 'FAIL  %s\n' "$label"
    failures=$((failures + 1))
  fi
}

echo "== openspec/ is gone =="
assert 'openspec/ is not in the tree' test ! -e "$ROOT/openspec"
assert 'git tracks nothing under openspec/' test -z "$(git -C "$ROOT" ls-files -- openspec)"

if [[ $failures -gt 0 ]]; then
  echo "$failures case(s) failed"
  exit 1
fi
echo "All cases passed"
