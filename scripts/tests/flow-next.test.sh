#!/usr/bin/env bash
# Structural test for the flow:next skill: pending evals that a story closed
# outside Claude left in its log (story 29).
# Run: bash scripts/tests/flow-next.test.sh
set -u

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SKILL="$ROOT/plugins/flow/skills/next/SKILL.md"
CASE="$ROOT/plugins/flow/evals/next-lists-pending-evals"
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

echo "== pending evals rule =="
# The phrase the generated flow-pair writes; it must match exactly.
# shellcheck disable=SC2016 # literal markdown backticks
assert 'next looks for the eval-pending phrase' has "$SKILL" '`make eval pending (needs Claude)`'
assert 'next lists them under Pending evals' has "$SKILL" 'Pending evals'
assert 'next names the command to run in Claude' has "$SKILL" 'make eval PLUGIN=<plugin>'
assert 'a later make eval result clears the entry' has "$SKILL" 'later Log line'

echo "== pending evals eval =="
assert 'case names itself' has "$CASE/case.yaml" 'name: next-lists-pending-evals'
assert 'case runs its scaffold' has "$CASE/case.yaml" 'scaffold_script: scaffold.sh'
assert 'scaffold seeds a story with the eval pending' has "$CASE/scaffold.sh" 'make eval pending (needs Claude)'
assert 'scaffold seeds a story whose eval ran later' has "$CASE/scaffold.sh" 'make eval PLUGIN=flow: pass'
assert 'grader expects Pending evals' has "$CASE/graders/pending-evals.md" 'Pending evals'

echo
if [[ $failures -gt 0 ]]; then
  echo "$failures case(s) failed"
  exit 1
fi
echo "All cases passed"
