#!/usr/bin/env bash
# Structural test for the flow:backlog skill: asserts only the contract strings
# other skills parse (story, pair, next). Run: bash scripts/tests/flow-backlog.test.sh
set -u

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SKILL="$ROOT/plugins/flow/skills/backlog/SKILL.md"
TEMPLATE="$ROOT/plugins/flow/skills/backlog/templates/backlog.md"
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

# frontmatter FILE: print the YAML block between the leading --- fences.
frontmatter() {
  awk 'NR == 1 { if ($0 != "---") exit 1; next } $0 == "---" { exit } { print }' "$1" 2>/dev/null
}

echo "== files =="
assert 'skill exists' test -f "$SKILL"
assert 'template exists' test -f "$TEMPLATE"

echo "== frontmatter =="
yaml=$(frontmatter "$SKILL")
assert 'name is backlog' grep -qx 'name: backlog' <<<"$yaml"
assert 'model-invocable (no disable-model-invocation)' test -f "$SKILL" -a -n "$yaml"
grep -q 'disable-model-invocation' <<<"$yaml" && {
  printf 'FAIL  frontmatter must not set disable-model-invocation\n'
  failures=$((failures + 1))
}

echo "== template =="
for s in '## Context' '## Backlog' 'Test command:' 'Single test:'; do
  assert "template has \"$s\"" has "$TEMPLATE" "$s"
done

echo "== skill contract =="
for s in '[ ]' '[~]' '[x] <sha>' '[-] split →' '[-] dropped' 'Requires: #' \
  'walking skeleton' 'docs/plans/<feature>/backlog.md' 'docs/plans/<project>/backlog.md'; do
  assert "skill documents \"$s\"" has "$SKILL" "$s"
done

echo
if [[ $failures -gt 0 ]]; then
  echo "$failures case(s) failed"
  exit 1
fi
echo "All cases passed"
