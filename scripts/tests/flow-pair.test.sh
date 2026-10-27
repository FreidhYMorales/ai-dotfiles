#!/usr/bin/env bash
# Structural test for the flow:pair skill: asserts the contract strings the
# red marker hook, the stop rules and the merge flow depend on.
# Run: bash scripts/tests/flow-pair.test.sh
set -u

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SKILL="$ROOT/plugins/flow/skills/pair/SKILL.md"
TDD="$ROOT/plugins/flow/skills/pair/references/strict-tdd.md"
WUC="$ROOT/plugins/toolkit/skills/work-unit-commits/SKILL.md"
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

# has_re FILE ERE: FILE exists and matches the extended regex.
has_re() { [[ -f $1 ]] && grep -qE -- "$2" "$1"; }

# frontmatter FILE: print the YAML block between the leading --- fences.
frontmatter() {
  awk 'NR == 1 { if ($0 != "---") exit 1; next } $0 == "---" { exit } { print }' "$1" 2>/dev/null
}

echo "== files =="
assert 'skill exists' test -f "$SKILL"
assert 'strict-tdd reference exists' test -f "$TDD"

echo "== frontmatter =="
yaml=$(frontmatter "$SKILL")
assert 'name is pair' grep -qx 'name: pair' <<<"$yaml"
assert 'slash-only (disable-model-invocation: true)' grep -qx 'disable-model-invocation: true' <<<"$yaml"
assert 'description starts with the explicit-use line' \
  grep -qE '^description: "?Explicit use only: /flow:pair NN\.' <<<"$yaml"
assert 'description excludes planning and backlog work' grep -qF 'Not for planning or backlog work' <<<"$yaml"

echo "== red marker and branch =="
for s in 'git rev-parse --git-path flow-pair-red' 'story/NN-' 'git merge --no-ff' \
  'Risk:' 'flow:verifier' 'no runnable test'; do
  assert "skill documents \"$s\"" has "$SKILL" "$s"
done
assert 'mode B requires Risk: none' has_re "$SKILL" 'Mode B.*Risk: none'
assert 'forbids --no-verify' has_re "$SKILL" '[Nn]ever.*--no-verify'
assert 'forbids git add -A' has_re "$SKILL" '[Nn]ever.*git add -A'
assert 'documents the tamper check on test files' has_re "$SKILL" 'git diff <test-commit>'

echo "== stop rules =="
for s in 'design decision' 'unrequested' 'existing test' 'two failed attempts' \
  '50 lines' 'hook rejects'; do
  assert "stop rule \"$s\"" has "$SKILL" "$s"
done

echo "== strict tdd =="
for s in 'Three Laws' 'Triangulat' 'Banned assertion' 'layer'; do
  assert "strict-tdd covers \"$s\"" has "$TDD" "$s"
done
assert 'strict-tdd drops SDD wiring' test -f "$TDD" -a -z "$(grep -iw 'sdd' "$TDD" 2>/dev/null)"

echo "== work-unit-commits exception =="
assert 'work-unit-commits names /flow:pair' has "$WUC" '/flow:pair'

echo
if [[ $failures -gt 0 ]]; then
  echo "$failures case(s) failed"
  exit 1
fi
echo "All cases passed"
