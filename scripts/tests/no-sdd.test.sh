#!/usr/bin/env bash
# Structural test for the retired sdd workflow: docs, skills and config name
# only the backlog -> story -> pair loop.
# Run: bash scripts/tests/no-sdd.test.sh
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

# no_sdd FILE: FILE exists and has no case-insensitive whole-word "sdd".
no_sdd() { [[ -f $1 ]] && ! grep -qiw 'sdd' "$1"; }

echo "== docs name only the loop =="
assert 'README names no sdd' no_sdd "$ROOT/README.md"
assert 'multi-agent doc names no sdd' no_sdd "$ROOT/docs/multi-agent.md"
assert 'upstream list names no sdd' no_sdd "$ROOT/upstreams.json"

if [[ $failures -gt 0 ]]; then
  echo "$failures case(s) failed"
  exit 1
fi
echo "All cases passed"
