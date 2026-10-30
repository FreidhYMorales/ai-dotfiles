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

echo "== the goldens are current and hold no Claude-only form =="
VERIFY="$ROOT/scripts/gen-agents/verify.sh"
verify() {
  LAST_OUTPUT=$(GEN_SOURCE="$1" bash "$VERIFY" 2>&1)
  LAST_EXIT=$?
}
verify "$ROOT"
assert 'this repo verifies' test "$LAST_EXIT" -eq 0
[[ $LAST_EXIT -eq 0 ]] || printf '%s\n' "$LAST_OUTPUT"

# A source change the goldens were not regenerated for.
STALE="$TMP_ROOT/stale"
mkdir -p "$STALE/plugins"
cp -r "$ROOT/plugins/flow" "$STALE/plugins/"
printf '\nA line the goldens lack.\n' >>"$STALE/plugins/flow/skills/plan-review/SKILL.md"
verify "$STALE"
assert 'a stale golden fails' test "$LAST_EXIT" -ne 0
assert 'stale: names the file' grep -q 'antigravity/skills/flow-plan-review/SKILL.md' <<<"$LAST_OUTPUT"

# A Claude-only form the rewrite does not cover.
LEFT="$TMP_ROOT/leftover"
mkdir -p "$LEFT/plugins"
cp -r "$ROOT/plugins/flow" "$LEFT/plugins/"
# shellcheck disable=SC2016 # a literal Claude-only form
printf '\nSee ${CLAUDE_PLUGIN_ROOT}/agents.\n' >>"$LEFT/plugins/flow/agents/plan-reviewer.md"
verify "$LEFT"
assert 'a leftover fails' test "$LAST_EXIT" -ne 0
assert 'leftover: names the file and the form' \
  grep -q 'opencode/agents/flow-plan-reviewer.md.*CLAUDE_PLUGIN_ROOT' <<<"$LAST_OUTPUT"

echo "== bare support-file references =="
# A copy of the sources whose plan-review names support files of its own.
REFS="$TMP_ROOT/refs"
mkdir -p "$REFS/plugins"
cp -r "$ROOT/plugins/flow" "$REFS/plugins/"
REFS_SKILL="$REFS/plugins/flow/skills/plan-review"
mkdir -p "$REFS_SKILL/references" "$REFS_SKILL/templates" "$REFS_SKILL/cheatsheets" "$REFS_SKILL/assets"
touch "$REFS_SKILL/references/x.md" "$REFS_SKILL/templates/y.md" "$REFS_SKILL/cheatsheets/z.md" "$REFS_SKILL/assets/w.json"
cat >>"$REFS_SKILL/SKILL.md" <<'EOF'

Read `references/x.md`, then fill `templates/y.md`.

- [references/x.md](references/x.md) — the notes.

Size it with `../pair/references/high-risk.md`.

Put fixtures in `assets/` and notes in `references/missing.md`.

Use `cheatsheets/z.md` with `assets/w.json`.
EOF
REFS_OUT="$TMP_ROOT/refs-out"
LAST_OUTPUT=$(GEN_SOURCE="$REFS" GEN_REPO_PATH="$REPO_PATH" bash "$GEN" "$REFS_OUT" 2>&1)
LAST_EXIT=$?
assert 'refs: generator exits 0' test "$LAST_EXIT" -eq 0
for target in opencode antigravity; do
  # shellcheck disable=SC2016 # literal markdown backticks
  assert "refs: $target own files become absolute" grep -qF \
    'Read `"/repo path/plugins/flow/skills/plan-review/references/x.md"`, then fill `"/repo path/plugins/flow/skills/plan-review/templates/y.md"`.' \
    "$REFS_OUT/$target/skills/flow-plan-review/SKILL.md"
  # shellcheck disable=SC2016 # literal markdown backticks
  assert "refs: $target markdown link becomes absolute" grep -qxF -e \
    '- `"/repo path/plugins/flow/skills/plan-review/references/x.md"` — the notes.' \
    "$REFS_OUT/$target/skills/flow-plan-review/SKILL.md"
  # shellcheck disable=SC2016 # literal markdown backticks
  assert "refs: $target sibling skill file becomes absolute" grep -qxF \
    'Size it with `"/repo path/plugins/flow/skills/pair/references/high-risk.md"`.' \
    "$REFS_OUT/$target/skills/flow-plan-review/SKILL.md"
  # shellcheck disable=SC2016 # literal markdown backticks
  assert "refs: $target directory prose and missing files stay" grep -qxF \
    'Put fixtures in `assets/` and notes in `references/missing.md`.' \
    "$REFS_OUT/$target/skills/flow-plan-review/SKILL.md"
  # shellcheck disable=SC2016 # literal markdown backticks
  assert "refs: $target cheatsheets and assets become absolute" grep -qxF \
    'Use `"/repo path/plugins/flow/skills/plan-review/cheatsheets/z.md"` with `"/repo path/plugins/flow/skills/plan-review/assets/w.json"`.' \
    "$REFS_OUT/$target/skills/flow-plan-review/SKILL.md"
done

# A bare reference the rewrite does not cover: plain prose, no backticks.
BARE="$TMP_ROOT/bare"
mkdir -p "$BARE/plugins"
cp -r "$ROOT/plugins/flow" "$BARE/plugins/"
mkdir -p "$BARE/plugins/flow/skills/plan-review/references"
touch "$BARE/plugins/flow/skills/plan-review/references/x.md"
printf '\nSee references/x.md for details.\n' >>"$BARE/plugins/flow/skills/plan-review/SKILL.md"
verify "$BARE"
assert 'a bare support path fails' test "$LAST_EXIT" -ne 0
assert 'bare: names the file and line' grep -qE \
  'bare support path: opencode/skills/flow-plan-review/SKILL\.md:[0-9]+:.*references/x\.md' <<<"$LAST_OUTPUT"

echo "== agy agents that use engram =="
# A copy of the sources whose reviewer also asks for an engram tool.
MEM="$TMP_ROOT/mem"
mkdir -p "$MEM/plugins"
cp -r "$ROOT/plugins/flow" "$MEM/plugins/"
awk '/^tools: / { $0 = $0 ", mcp__engram__mem_search" } 1' "$ROOT/plugins/flow/agents/plan-reviewer.md" \
  >"$MEM/plugins/flow/agents/plan-reviewer.md"
MEM_OUT="$TMP_ROOT/mem-out"
LAST_OUTPUT=$(GEN_SOURCE="$MEM" GEN_REPO_PATH="$REPO_PATH" bash "$GEN" "$MEM_OUT" 2>&1)
LAST_EXIT=$?
assert 'mem: generator exits 0' test "$LAST_EXIT" -eq 0
[[ $LAST_EXIT -eq 0 ]] || printf '%s\n' "$LAST_OUTPUT"
# frontmatter FILE: the lines between the two '---' markers.
frontmatter() { awk 'NR > 1 && /^---$/ { exit } NR > 1' "$1"; }
MEM_FM=$(frontmatter "$MEM_OUT/antigravity/agents/flow-plan-reviewer.md" 2>/dev/null)
ENGRAM_BLOCK='mcpServers:
  - name: engram
    command: engram
    args:
      - mcp
      - --tools=agent'
assert 'mem: engram declared under mcpServers' test "${MEM_FM#*"$ENGRAM_BLOCK"}" != "$MEM_FM"
assert 'mem: no engram name in tools' test -z "$(grep -E '^  - .*mem_' <<<"$MEM_FM")"
# The real reviewer has no engram tool.
assert 'mem: an agent without engram has no mcpServers' \
  test -z "$(frontmatter "$OUT/antigravity/agents/flow-plan-reviewer.md" | grep '^mcpServers:')"

if [[ $failures -gt 0 ]]; then
  echo "$failures case(s) failed"
  exit 1
fi
echo "All cases passed"
