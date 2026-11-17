#!/usr/bin/env bash
# Structural test for the toolkit:delegate-local skill: asserts the worker is
# handed the focused test, never the full suite.
# Run: bash scripts/tests/toolkit-delegate-local.test.sh
# shellcheck disable=SC2016 # literal markdown backticks
set -u

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SKILL="$ROOT/plugins/toolkit/skills/delegate-local/SKILL.md"
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

# line_has PATTERN TEXT: the first SKILL.md line matching the ERE PATTERN
# contains TEXT literally.
line_has() { grep -E -m1 -- "$1" "$SKILL" 2>/dev/null | grep -qF -- "$2"; }

PROMPT='^1\. Write the task as a prompt'

echo "== the worker prompt names the focused test =="
assert 'the prompt names the backlog Single test: command' \
  line_has "$PROMPT" "the backlog's \`Single test:\` command filled in for the task"
assert 'the prompt falls back to Test command: when Single test: is missing or none' \
  line_has "$PROMPT" "the \`Test command:\` when the backlog has no \`Single test:\` or it is \`none\`"
assert 'the prompt falls back to make check when there is no backlog' \
  line_has "$PROMPT" '`make check` when there is no backlog'
assert 'the prompt never hands the worker the full suite' \
  line_has "$PROMPT" 'never the full suite'

if ((failures)); then
  printf '%d case(s) failed\n' "$failures"
  exit 1
fi
echo 'All cases passed'
