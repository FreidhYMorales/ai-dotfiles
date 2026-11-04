#!/usr/bin/env bash
# The look cases that advance the clock over several polls declare a 30 s
# budget, so a slow CI runner never trips the harness's 5 s watchdog
# (story 18). Run: bash scripts/tests/look-budgets.test.sh
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

# declares FILE NAME: the look case NAME in FILE opens with the 30 s budget.
declares() {
  rg -qF "test('$2', { timeoutMs: 30_000 }, async" "$ROOT/plugins/look/tests/$1"
}

assert 'agent.list two-polls case has the 30 s budget' declares agent.test.tsx \
  'an agent missing from agent.list on two polls in a row is stopped, with no alert'

echo
if [[ $failures -gt 0 ]]; then
  echo "$failures case(s) failed"
  exit 1
fi
echo "All cases passed"
