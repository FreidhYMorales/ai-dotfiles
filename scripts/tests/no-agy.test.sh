#!/usr/bin/env bash
# Structural test for the retired Antigravity (agy) support: the open items
# no longer name it.
# Run: bash scripts/tests/no-agy.test.sh
set -u

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
IDEAS="$ROOT/docs/ideas.md"
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

# idea N: the ideas log section of idea N, up to the next level-2 heading.
idea() { awk -v h="## $1. " 'index($0, h) == 1 { on = 1; print; next } /^## / { on = 0 } on' "$IDEAS"; }

echo "== open items name no agy =="
idea29=$(idea 29)
assert 'idea 29 is found' test -n "$idea29"
assert 'idea 29 is done' rg -qxF -- '- Done: retire-antigravity stories 01-04 (2026-11-18).' <<<"$idea29"
idea20=$(idea 20)
assert 'idea 20 is found' test -n "$idea20"
assert 'idea 20 still names the plugins and the marketplace' rg -q 'plugins.*marketplace' <<<"$idea20"
assert 'idea 20 names no agy' test -z "$(rg -i 'agy' <<<"$idea20")"
assert 'multi-agent-port #47 is dropped' rg -q '^47\. \[-\] dropped: superseded by retire-antigravity' \
  "$ROOT/docs/plans/multi-agent-port/backlog.md"

if [[ $failures -gt 0 ]]; then
  echo "$failures case(s) failed"
  exit 1
fi
echo "All cases passed"
