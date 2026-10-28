#!/usr/bin/env bash
# Structural test for what the marketplace ships: the retired sdd plugin is
# gone, and the upstream notes it carried are kept as reference.
# Run: bash scripts/tests/plugins.test.sh
set -u

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
MARKETPLACE="$ROOT/.claude-plugin/marketplace.json"
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

# json_true FILE FILTER: FILTER evaluates to true on FILE.
json_true() { jq -e "$2" "$1" >/dev/null 2>&1; }

echo "== marketplace: sdd is retired =="
assert 'marketplace offers no sdd plugin' json_true "$MARKETPLACE" '[.plugins[].name] | index("sdd") == null'
assert 'marketplace description drops Spec-Driven Development' json_true "$MARKETPLACE" '.description | test("Spec-Driven Development") | not'
assert 'plugins/sdd is gone' test ! -e "$ROOT/plugins/sdd"

echo "== upstream notes are kept =="
assert 'upstream README is kept' test -f "$ROOT/docs/upstream/README.md"
assert 'gentle-ai CLAUDE.md is kept' test -f "$ROOT/docs/upstream/gentle-ai-CLAUDE.md"

if [[ $failures -gt 0 ]]; then
  echo "$failures case(s) failed"
  exit 1
fi
echo "All cases passed"
