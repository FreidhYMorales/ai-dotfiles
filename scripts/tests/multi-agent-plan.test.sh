#!/usr/bin/env bash
# Structural test for the multi-agent-port plan: it ports the backlog -> story
# -> pair loop, not the retired sdd workflow.
# Run: bash scripts/tests/multi-agent-plan.test.sh
set -u

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
PLAN="$ROOT/docs/plans/multi-agent-port/plan.md"
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

echo "== multi-agent-port names no sdd =="
assert 'plan names no sdd' test -f "$PLAN" -a -z "$(grep -iw 'sdd' "$PLAN")"

if [[ $failures -gt 0 ]]; then
  echo "$failures case(s) failed"
  exit 1
fi
echo "All cases passed"
