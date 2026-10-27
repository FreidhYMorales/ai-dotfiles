#!/usr/bin/env bash
# Structural test for the flow:story skill: asserts only the contract strings
# other skills parse (pair, verifier) and the single high-risk list.
# Run: bash scripts/tests/flow-story.test.sh
set -u

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SKILL="$ROOT/plugins/flow/skills/story/SKILL.md"
TEMPLATE="$ROOT/plugins/flow/skills/story/templates/story.md"
RISK="$ROOT/plugins/flow/skills/pair/references/high-risk.md"
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

# has_line FILE TEXT: FILE has a line that is exactly TEXT.
has_line() { [[ -f $1 ]] && grep -qxF -- "$2" "$1"; }

# has_re FILE ERE: FILE exists and matches the extended regex.
has_re() { [[ -f $1 ]] && grep -qE -- "$2" "$1"; }

# frontmatter FILE: print the YAML block between the leading --- fences.
frontmatter() {
  awk 'NR == 1 { if ($0 != "---") exit 1; next } $0 == "---" { exit } { print }' "$1" 2>/dev/null
}

echo "== files =="
assert 'skill exists' test -f "$SKILL"
assert 'template exists' test -f "$TEMPLATE"
assert 'high-risk reference exists' test -f "$RISK"

echo "== frontmatter =="
yaml=$(frontmatter "$SKILL")
assert 'name is story' grep -qx 'name: story' <<<"$yaml"
assert 'model-invocable (no disable-model-invocation)' test -f "$SKILL" -a -n "$yaml"
grep -q 'disable-model-invocation' <<<"$yaml" && {
  printf 'FAIL  frontmatter must not set disable-model-invocation\n'
  failures=$((failures + 1))
}

echo "== template =="
for s in '## Story' '## Acceptance criteria' '## Plan' '## Out of scope' \
  '## Suggestions (your call)' '## Size' '## Log'; do
  assert "template has \"$s\"" has_line "$TEMPLATE" "$s"
done

echo "== skill contract =="
for s in 'Given' 'When' 'Then' '2-3' '[-] split →' '[~]' 'Risk: none' \
  'small' 'pair/references/high-risk.md'; do
  assert "skill documents \"$s\"" has "$SKILL" "$s"
done
assert 'skill states the chat-only rule (small + Risk: none)' \
  has_re "$SKILL" '[Cc]hat-only.*small.*Risk: none'

echo "== high-risk list =="
for n in 1 2 3 4 5 6; do
  assert "item $n is numbered" has_re "$RISK" "^$n\. "
done
assert 'documents "Risk: item"' has "$RISK" 'Risk: item'
assert 'documents "Risk: none"' has "$RISK" 'Risk: none'

echo
if [[ $failures -gt 0 ]]; then
  echo "$failures case(s) failed"
  exit 1
fi
echo "All cases passed"
