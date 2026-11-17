#!/usr/bin/env bash
# Structural test for the toolkit:ship skill: asserts it runs make check once,
# with the long-run wording, and again only when a rebase changed the tree.
# Run: bash scripts/tests/toolkit-ship.test.sh
# shellcheck disable=SC2016 # literal markdown backticks
set -u

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SKILL="$ROOT/plugins/toolkit/skills/ship/SKILL.md"
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

STEP1='^1\. `make check`'

echo "== step 1 runs make check once, with the long-run wording =="
assert 'step 1 allows up to 10 minutes' \
  line_has "$STEP1" 'allow up to 10 minutes (Claude: Bash `timeout` 600000), or run it in the background and read the result'

GATE='^\| Branch is behind its upstream \|'

echo "== a rebase reruns make check only when it changed the tree =="
assert 'the gate saves HEAD before the rebase' line_has "$GATE" 'Save `git rev-parse HEAD`, `git pull --rebase`'
assert 'the gate reruns make check only on changed files' \
  line_has "$GATE" 'rerun `make check` only when `git diff --name-only <saved sha> HEAD` lists files'

NOWF='^\| No active workflow \|'
DONE='^- Done means CI is green'

echo "== with no active workflow, ship skips the CI watch =="
assert 'the gate detects no active workflow with gh workflow list --all' \
  line_has "$NOWF" '`gh workflow list --all` shows no workflow `active`'
assert 'the gate looks for no run and says why CI was skipped' \
  line_has "$NOWF" 'look for no run; say CI was skipped because no workflow is active'
assert 'the gate reports done with make check green and the pushed SHA' \
  line_has "$NOWF" 'done is `make check` green and the pushed SHA'
assert 'done means CI green only when a workflow is active' \
  line_has "$DONE" 'when the repo has an active workflow'

WATCH='^5\. '

echo "== with an active workflow, ship still watches the run =="
assert 'step 5 watches the run only when a workflow is active' \
  line_has "$WATCH" 'When `gh workflow list --all` shows an `active` workflow, find the run for the pushed SHA'
assert 'step 5 still watches the run until it is green' \
  line_has "$WATCH" '`gh run watch <id> --exit-status`'
assert 'step 5 points to the no-active-workflow gate otherwise' \
  line_has "$WATCH" 'otherwise follow the "No active workflow" gate'

if ((failures)); then
  printf '%d case(s) failed\n' "$failures"
  exit 1
fi
echo 'All cases passed'
