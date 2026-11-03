#!/usr/bin/env bash
# Structural test for the retired openspec/ tree: it is gone, and only history
# still names it.
# Run: bash scripts/tests/no-openspec.test.sh
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

# no_openspec PATH: no file under PATH names openspec.
no_openspec() { ! rg -q openspec "$1"; }

echo "== openspec/ is gone =="
assert 'openspec/ is not in the tree' test ! -e "$ROOT/openspec"
assert 'git tracks nothing under openspec/' test -z "$(git -C "$ROOT" ls-files -- openspec)"

echo "== flow lookups name only docs/plans =="
SKILLS="$ROOT/plugins/flow/skills"
GOLDEN="$ROOT/scripts/gen-agents/golden"
for s in backlog story pair plan plan-review fill-gaps research foundation handoff; do
  # Backticks are literal markdown.
  # shellcheck disable=SC2016
  assert "$s looks up docs/plans/<feature>/" rg -qF '`docs/plans/<feature>/' "$SKILLS/$s/SKILL.md"
  assert "$s names no openspec" no_openspec "$SKILLS/$s/SKILL.md"
done
assert 'the goldens are present' test -d "$GOLDEN/opencode/skills" -a -d "$GOLDEN/antigravity/skills"
assert 'no golden names openspec' no_openspec "$GOLDEN"

echo "== only history names openspec =="
hits=$(cd "$ROOT" && rg -l openspec --hidden -g '!.git')
# Guard against a scan that finds nothing at all: the ideas log must show up.
assert 'the scan sees the ideas log' rg -qx 'docs/ideas.md' <<<"$hits"
stray=$(rg -v '^(docs/plans/|docs/upstream/|docs/ideas\.md$|scripts/tests/no-openspec\.test\.sh$)' <<<"$hits")
assert 'no file outside history names openspec' test -z "$stray"
[[ -n $stray ]] && printf '%s\n' "$stray"

if [[ $failures -gt 0 ]]; then
  echo "$failures case(s) failed"
  exit 1
fi
echo "All cases passed"
