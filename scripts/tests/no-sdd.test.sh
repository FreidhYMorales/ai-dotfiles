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

echo "== no SDD project config =="
assert 'openspec/config.yaml is gone' test ! -e "$ROOT/openspec/config.yaml"

echo "== flow names no sdd and counts no files =="
FLOW="$ROOT/plugins/flow"
assert 'high-risk list names no sdd' no_sdd "$FLOW/skills/pair/references/high-risk.md"
for skill in plan research foundation; do
  assert "$skill delegates by understanding, not 4+ files" test -f "$FLOW/skills/$skill/SKILL.md" -a -z "$(grep -F '4+ files' "$FLOW/skills/$skill/SKILL.md")"
done
assert 'flow plugin is 0.10.0' test "$(jq -r .version "$FLOW/.claude-plugin/plugin.json")" = 0.10.0
assert 'marketplace lists flow 0.10.0' \
  test "$(jq -r '.plugins[] | select(.name == "flow") | .version' "$ROOT/.claude-plugin/marketplace.json")" = 0.10.0

echo "== toolkit skills name no sdd =="
TOOLKIT="$ROOT/plugins/toolkit"
assert 'work-unit-commits names no sdd' no_sdd "$TOOLKIT/skills/work-unit-commits/SKILL.md"
assert 'chained-pr names no sdd' no_sdd "$TOOLKIT/skills/chained-pr/SKILL.md"
assert 'toolkit plugin is 0.14.0' test "$(jq -r .version "$TOOLKIT/.claude-plugin/plugin.json")" = 0.14.0
assert 'marketplace lists toolkit 0.14.0' \
  test "$(jq -r '.plugins[] | select(.name == "toolkit") | .version' "$ROOT/.claude-plugin/marketplace.json")" = 0.14.0

if [[ $failures -gt 0 ]]; then
  echo "$failures case(s) failed"
  exit 1
fi
echo "All cases passed"
