#!/usr/bin/env bash
# Structural test for the toolkit:ship skill: asserts it runs make check once,
# with the long-run wording, and again only when a rebase changed the tree.
# Run: bash scripts/tests/toolkit-ship.test.sh
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

if ((failures)); then
  printf '%d case(s) failed\n' "$failures"
  exit 1
fi
echo 'All cases passed'
