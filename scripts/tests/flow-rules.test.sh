#!/usr/bin/env bash
# Structural test for the always-on rules: work is sized, delegated and verified
# by understanding, risk and resumability, never by file counts.
# Run: bash scripts/tests/flow-rules.test.sh
set -u

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
RULES="$ROOT/claude/CLAUDE.md"
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

# has FILE TEXT: FILE exists and contains TEXT literally.
has() { [[ -f $1 ]] && grep -qF -- "$2" "$1"; }

echo "== rules: risk comes from the single high-risk list =="
assert 'rules point to the high-risk list' has "$RULES" 'plugins/flow/skills/pair/references/high-risk.md'

if [[ $failures -gt 0 ]]; then
  echo "$failures case(s) failed"
  exit 1
fi
echo "All cases passed"
