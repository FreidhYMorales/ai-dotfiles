#!/usr/bin/env bash
# Golden tests for the OpenCode and Antigravity generator.
# Run: bash scripts/tests/gen-agents.test.sh
set -u

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
GEN="$ROOT/scripts/gen-agents/gen.sh"
GOLDEN="$ROOT/scripts/gen-agents/golden"
# The repo path written into the output; fixed so goldens do not depend on
# where the checkout lives. It has a space, like the real repo path.
REPO_PATH="/repo path"
failures=0
TMP_ROOT=$(mktemp -d)
trap 'rm -rf "$TMP_ROOT"' EXIT

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

# generate DIR: run the generator into DIR; output in $LAST_OUTPUT.
LAST_OUTPUT=""
LAST_EXIT=0
generate() {
  LAST_OUTPUT=$(GEN_REPO_PATH="$REPO_PATH" bash "$GEN" "$1" 2>&1)
  LAST_EXIT=$?
}

# same_as_golden REL: the generated file REL matches its golden fixture.
same_as_golden() { diff -u "$GOLDEN/$1" "$OUT/$1"; }

OUT="$TMP_ROOT/out"
generate "$OUT"
assert 'generator exits 0' test "$LAST_EXIT" -eq 0
[[ $LAST_EXIT -eq 0 ]] || printf '%s\n' "$LAST_OUTPUT"

echo "== OpenCode plan reviewer agent =="
assert 'agents/flow-plan-reviewer.md matches golden' same_as_golden opencode/agents/flow-plan-reviewer.md

echo "== OpenCode plan-review skill and command =="
assert 'skills/flow-plan-review/SKILL.md matches golden' same_as_golden opencode/skills/flow-plan-review/SKILL.md
assert 'commands/flow-plan-review.md matches golden' same_as_golden opencode/commands/flow-plan-review.md

echo "== Antigravity plan reviewer agent =="
# Only the registry tool names story 16 proved; Glob and Bash are left out.
assert 'agents/flow-plan-reviewer.md matches golden' same_as_golden antigravity/agents/flow-plan-reviewer.md

echo "== Antigravity plan-review skill =="
assert 'skills/flow-plan-review/SKILL.md matches golden' same_as_golden antigravity/skills/flow-plan-review/SKILL.md

echo "== a tool outside the agy map is an error =="
# A copy of the sources whose reviewer also asks for WebFetch.
SRC="$TMP_ROOT/src"
mkdir -p "$SRC/plugins"
cp -r "$ROOT/plugins/flow" "$SRC/plugins/"
awk '/^tools: / { $0 = $0 ", WebFetch" } 1' "$ROOT/plugins/flow/agents/plan-reviewer.md" \
  >"$SRC/plugins/flow/agents/plan-reviewer.md"
LAST_OUTPUT=$(GEN_SOURCE="$SRC" GEN_REPO_PATH="$REPO_PATH" bash "$GEN" "$TMP_ROOT/unmapped" 2>&1)
LAST_EXIT=$?
assert 'generator fails' test "$LAST_EXIT" -ne 0
assert 'error names the tool' grep -q 'WebFetch' <<<"$LAST_OUTPUT"

if [[ $failures -gt 0 ]]; then
  echo "$failures case(s) failed"
  exit 1
fi
echo "All cases passed"
