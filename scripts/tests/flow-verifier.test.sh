#!/usr/bin/env bash
# Structural test for the flow:verifier agent and how /flow:pair calls it:
# asserts only the contract strings pair parses and the read-only tool set.
# Run: bash scripts/tests/flow-verifier.test.sh
set -u

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
AGENT="$ROOT/plugins/flow/agents/verifier.md"
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

echo "== agent: read-only verifier =="
assert 'agent exists' test -f "$AGENT"
assert 'name is verifier' grep -qx 'name: verifier' <<<"$(frontmatter "$AGENT")"
assert 'tools are exactly Read, Grep, Glob, Bash' grep -qx 'tools: Read, Grep, Glob, Bash' <<<"$(frontmatter "$AGENT")"
assert 'states it never changes files' has "$AGENT" 'Never create, edit or delete files'
assert 'reads the story file' has "$AGENT" 'stories/NN-<slug>.md'
assert 'reads the branch diff against main' has "$AGENT" 'git diff main...HEAD'
assert 'reads the pair references' has "$AGENT" 'pair/references/'

echo "== agent: report shape pair parses =="
assert 'has a fixed report section' has "$AGENT" '## Report'
assert 'one row per acceptance criterion' has "$AGENT" '| Criterion | Result | Evidence |'
assert 'checks test commit before code commit' has "$AGENT" 'Commit order'
assert 'checks committed tests were not changed' has "$AGENT" 'Tamper check'
assert 'security checklist for item 2' has "$AGENT" 'Security (item 2)'
assert 'verdict line format' has "$AGENT" 'Verdict: PASS | FAIL | NEEDS DECISION'

PAIR="$ROOT/plugins/flow/skills/pair/SKILL.md"
echo "== pair: bounded corrections =="
assert 'one correction batch on FAIL' has "$PAIR" 'one correction batch'
assert 'one recheck by the verifier' has "$PAIR" 'one recheck'
assert 'second FAIL hands it to the user' has "$PAIR" 'a second FAIL ends with NEEDS DECISION'

echo "== pair: verifier only for high risk =="
assert 'calls the verifier when Risk names an item' has "$PAIR" 'High-risk story (any item): invoke the `flow:verifier` agent'
assert 'never calls it for Risk: none' has "$PAIR" '`Risk: none`: no verifier'

echo
if [[ $failures -gt 0 ]]; then
  echo "$failures case(s) failed"
  exit 1
fi
echo "All cases passed"
