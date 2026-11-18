#!/usr/bin/env bash
# Structural test for the tiered-checks docs: README, docs/multi-agent.md, the
# CI workflow and idea 28 describe the two tiers (check-fast between turns,
# make check at a story's end, at ship and in CI), the check-fast contract and
# what a green hook means.
# Run: bash scripts/tests/tiered-docs.test.sh
# shellcheck disable=SC2016 # literal markdown backticks
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

# line_has FILE PATTERN TEXT: the first FILE line matching the ERE PATTERN
# contains TEXT literally.
line_has() { grep -E -m1 -- "$2" "$1" 2>/dev/null | grep -qF -- "$3"; }

GREEN='when the tree is dirty, a green hook means the fast tier passed on the branch'"'"'s changes; a clean tree runs nothing'

README="$ROOT/README.md"
echo "== README describes both tiers and what a green hook means =="
assert 'the toolkit row: require-check prefers check-fast' \
  line_has "$README" '^\| `plugins/toolkit/`' 'runs `make check-fast` from the git root when the Makefile defines it, else `make check`'
assert 'verification names both tiers' \
  line_has "$README" '^Agent output is accepted' 'Between turns the `require-check` Stop hook runs `make check-fast`; a story, a ship and CI are done when `make check` passes'
assert 'verification says what a green hook means' \
  line_has "$README" '^Agent output is accepted' "$GREEN"
assert 'the Makefile row: check-fast is static and changed-files only' \
  line_has "$README" '^\| `Makefile`, `scripts/`' '`make check-fast`: shellcheck on the changed scripts plus JSON/structure/settings validation, skill lint and workflow lint; no tests or bench'
assert 'the Makefile row: who runs each target' \
  line_has "$README" '^\| `Makefile`, `scripts/`' '`check-fast` run by `require-check` between turns; `check` at a story'"'"'s end, at ship and in CI'

MULTI="$ROOT/docs/multi-agent.md"
echo "== docs/multi-agent.md: the agy Stop gate runs the fast tier =="
assert 'the Hooks row names check-fast with the make check fallback' \
  line_has "$MULTI" '^\| Hooks \|' 'the Stop gate (`require-check`: `make check-fast` when the Makefile defines it, else `make check`)'
assert 'OpenCode runs check-fast before done, else make check' \
  line_has "$MULTI" '^The repo-root `AGENTS.md`' 'OpenCode runs `make check-fast` before saying done when the Makefile defines it, else `make check` (it has no Stop gate)'

WORKFLOW="$ROOT/.github/workflows/check.yml"
echo "== the CI workflow header: CI runs the full tier =="
assert 'the header says CI runs the full make check and the hook check-fast' \
  line_has "$WORKFLOW" '^# Runs ' 'the full make check, the gate for a story, a ship and CI; between turns the require-check Stop hook runs make check-fast'

# idea28 prints the idea 28 section of docs/ideas.md.
idea28() { awk '/^## 28\./ { on = 1; print; next } on && /^## / { exit } on' "$ROOT/docs/ideas.md"; }
idea28_has() { idea28 | grep -qF -- "$1"; }

echo "== idea 28 records what a green hook means and drops the parallel runner =="
assert 'idea 28 section is found' idea28_has '## 28. Tiered checks'
assert 'idea 28 says what a green hook means' idea28_has "$GREEN"
assert 'idea 28 drops the parallel test runner' \
  idea28_has 'no parallel test runner (`scripts/run-tests.sh` is already parallel)'

if ((failures)); then
  printf '%d case(s) failed\n' "$failures"
  exit 1
fi
echo 'All cases passed'
