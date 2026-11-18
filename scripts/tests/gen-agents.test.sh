#!/usr/bin/env bash
# Golden tests for the OpenCode generator.
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

echo "== OpenCode verifier agent =="
# The Claude plugin-root fallback becomes the absolute references path. Its
# shell runs only read-only commands and make check without asking (story 28);
# the last matching rule wins in OpenCode 2.2.2, so rules after the allows
# deny rg --pre and git --output/--ext-diff and ask on a redirection.
assert 'agents/flow-verifier.md matches golden' same_as_golden opencode/agents/flow-verifier.md

echo "== OpenCode plan-review skill and command =="
assert 'skills/flow-plan-review/SKILL.md matches golden' same_as_golden opencode/skills/flow-plan-review/SKILL.md
assert 'commands/flow-plan-review.md matches golden' same_as_golden opencode/commands/flow-plan-review.md

echo "== OpenCode story loop skills and commands =="
for name in flow-backlog flow-story flow-pair toolkit-work-unit-commits; do
  assert "skills/$name/SKILL.md matches golden" same_as_golden "opencode/skills/$name/SKILL.md"
done
for name in flow-backlog flow-story flow-pair; do
  assert "commands/$name.md matches golden" same_as_golden "opencode/commands/$name.md"
done
# OpenCode 2.2.2 reads disable-model-invocation as "the model may not load
# this skill", so the /flow-pair command could not load it.
assert 'OpenCode pair stays loadable by its command' \
  test -f "$OUT/opencode/skills/flow-pair/SKILL.md" -a -z "$(grep -F 'disable-model-invocation' "$OUT/opencode/skills/flow-pair/SKILL.md" 2>/dev/null)"
# judgment-day is not generated, and pair's references are absolute paths.
# shellcheck disable=SC2016 # literal markdown backticks
assert 'OpenCode pair marks judgment-day Claude Code only' \
  grep -qF 'recommend `/toolkit-judgment-day` (Claude Code only)' "$OUT/opencode/skills/flow-pair/SKILL.md"
assert 'OpenCode pair no longer points at its base directory' \
  test -f "$OUT/opencode/skills/flow-pair/SKILL.md" -a -z "$(grep -F 'base directory' "$OUT/opencode/skills/flow-pair/SKILL.md" 2>/dev/null)"
assert 'OpenCode story reaches high-risk.md by an absolute path' \
  test -z "$(grep -E '`pair/references/' "$OUT/opencode/skills/flow-story/SKILL.md" 2>/dev/null)" -a -f "$OUT/opencode/skills/flow-story/SKILL.md"

echo "== OpenCode remaining skills and planning commands =="
# Every other flow and toolkit skill but judgment-day (story 30); only the
# planning path gets commands here, the rest in story 14 below.
REMAINING="flow-plan flow-research flow-fill-gaps flow-handoff flow-next flow-idea flow-split
  flow-integrate flow-foundation flow-bootstrap toolkit-ship toolkit-chained-pr toolkit-cli-tools
  toolkit-cognitive-doc-design toolkit-comment-writer toolkit-delegate-local toolkit-go-testing
  toolkit-skill-creator toolkit-skill-improver"
for name in $REMAINING; do
  assert "skills/$name/SKILL.md matches golden" same_as_golden "opencode/skills/$name/SKILL.md"
done
for name in flow-plan flow-fill-gaps; do
  assert "commands/$name.md matches golden" same_as_golden "opencode/commands/$name.md"
done

echo "== OpenCode remaining commands =="
# Every ported skill has a command that loads it (story 14); judgment-day stays
# Claude-only.
REMAINING_COMMANDS="toolkit-work-unit-commits flow-research flow-handoff flow-next flow-idea
  flow-split flow-integrate flow-foundation flow-bootstrap toolkit-ship toolkit-chained-pr
  toolkit-cli-tools toolkit-cognitive-doc-design toolkit-comment-writer toolkit-delegate-local
  toolkit-go-testing toolkit-skill-creator toolkit-skill-improver"
for name in $REMAINING_COMMANDS; do
  assert "commands/$name.md matches golden" same_as_golden "opencode/commands/$name.md"
done
# shellcheck disable=SC2016 # literal markdown backticks
assert 'the /flow-next command loads the flow-next skill' \
  grep -qxF 'Load the `flow-next` skill and follow it. $ARGUMENTS' "$OUT/opencode/commands/flow-next.md"
assert 'judgment-day gets no OpenCode command' test ! -e "$OUT/opencode/commands/toolkit-judgment-day.md"

echo "== OpenCode commands never shadow a built-in =="
# The TUI slash commands and aliases of OpenCode 2.2.5 (read from its binary,
# story 14) plus the server's init and review. Refresh on an OpenCode upgrade.
OPENCODE_BUILTINS="agents btw cd clear compact connect copy debug diff editor exit quit q export
  fork help highlights mcps models new open projects project pair web plugins redo reload rename
  restart sessions resume continue settings skills stats status terminal themes timeline undo
  update usage variants thinking effort worktrees init review"
collisions=""
for builtin in $OPENCODE_BUILTINS; do
  [[ -e $OUT/opencode/commands/$builtin.md ]] && collisions+="commands/$builtin.md "
done
assert 'no generated command shares a name with an OpenCode built-in' test -z "$collisions"
[[ -z $collisions ]] || printf 'colliding: %s\n' "$collisions"

echo "== OpenCode rules =="
# The shared rules plus the lines OpenCode's hooks do not cover (story 31):
# the make check gate and the raw support-file names; pause is a hook (#20).
assert 'AGENTS.md matches golden' same_as_golden opencode/AGENTS.md
# shellcheck disable=SC2016 # literal markdown backticks
assert 'OpenCode rules run make check-fast before done' \
  grep -qF 'Before saying work is done, when the tree has uncommitted changes, run `make check-fast` from the git root if the root Makefile has a `check-fast` target' "$OUT/opencode/AGENTS.md"
# shellcheck disable=SC2016 # literal markdown backticks
assert 'OpenCode rules fall back to make check without check-fast' \
  grep -qF 'target, else `make check` if it has a `check` target; fix any failure first' "$OUT/opencode/AGENTS.md"
assert 'OpenCode rules skip the gate on a red marker' grep -qF 'flow-pair-red' "$OUT/opencode/AGENTS.md"
# shellcheck disable=SC2016 # literal markdown backticks
assert 'OpenCode rules map support-file names' \
  grep -qF 'name `/flow:<skill>` or `/toolkit:<skill>`; in OpenCode that is `/flow-<skill>` or `/toolkit-<skill>`' "$OUT/opencode/AGENTS.md"
assert 'OpenCode rules hold no pause line' \
  test -f "$OUT/opencode/AGENTS.md" -a -z "$(grep -F 'pausa' "$OUT/opencode/AGENTS.md" 2>/dev/null)"

echo "== a skill story closes with the eval pending outside Claude =="
target=opencode
# shellcheck disable=SC2016 # literal markdown backticks
assert "$target pair records make eval pending in the Done step" \
  grep -qE '^7\. \*\*Done\.\*\*.*write `make eval pending \(needs Claude\)` in the story log' "$OUT/$target/skills/flow-pair/SKILL.md"

echo "== generated pair loops on the focused test =="
# Story tiered-checks/04: the generated copies carry the focused-test loop
# and the single full run on the final tree.
target=opencode
assert "$target pair reruns the focused test until green" \
  grep -qF 'rerun the focused test until green' "$OUT/$target/skills/flow-pair/SKILL.md"
# shellcheck disable=SC2016 # literal markdown backticks
assert "$target pair runs the Test command once on the final tree" \
  grep -qE '^6\. \*\*Check\.\*\*.*run the `Test command:` once on the final tree' "$OUT/$target/skills/flow-pair/SKILL.md"

echo "== generated ship runs make check once =="
# Story tiered-checks/06: the generated copies carry the long-run wording and
# rerun make check after a rebase only on changed files.
target=opencode
# shellcheck disable=SC2016 # literal markdown backticks
assert "$target ship allows up to 10 minutes in step 1" \
  grep -qE '^1\. `make check`.*allow up to 10 minutes' "$OUT/$target/skills/toolkit-ship/SKILL.md"
# shellcheck disable=SC2016 # literal markdown backticks
assert "$target ship reruns make check after a rebase only on changed files" \
  grep -qE '^\| Branch is behind its upstream \|.*rerun `make check` only when `git diff --name-only <saved sha> HEAD` lists files' \
  "$OUT/$target/skills/toolkit-ship/SKILL.md"

echo "== generated delegate-local hands the worker the focused test =="
# Story tiered-checks/09: only the OpenCode copy is pinned.
# shellcheck disable=SC2016 # literal markdown backticks
assert "opencode delegate-local prompt names the Single test: command" \
  grep -qE "^1\. Write the task as a prompt.*the backlog's \`Single test:\` command filled in for the task" \
  "$OUT/opencode/skills/toolkit-delegate-local/SKILL.md"
# shellcheck disable=SC2016 # literal markdown backticks
assert "opencode delegate-local reruns the full Test command: once after applying" \
  grep -qE '^6\. Apply:.*rerun the full `Test command:` \(or `make check`\) once on the applied tree' \
  "$OUT/opencode/skills/toolkit-delegate-local/SKILL.md"

echo "== generated ship skips the CI watch without an active workflow =="
# Story tiered-checks/12: only the OpenCode copy is pinned.
# shellcheck disable=SC2016 # literal markdown backticks
assert "opencode ship skips the CI watch when no workflow is active" \
  grep -qE '^\| No active workflow \|.*look for no run; say CI was skipped because no workflow is active' \
  "$OUT/opencode/skills/toolkit-ship/SKILL.md"
# shellcheck disable=SC2016 # literal markdown backticks
assert "opencode ship watches the run only when a workflow is active" \
  grep -qE '^5\. When `gh workflow list --all` shows an `active` workflow, find the run for the pushed SHA' \
  "$OUT/opencode/skills/toolkit-ship/SKILL.md"

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
cp -r "$ROOT/plugins/flow" "$ROOT/plugins/toolkit" "$STALE/plugins/"
cp -r "$ROOT/claude" "$STALE/"
printf '\nA line the goldens lack.\n' >>"$STALE/plugins/flow/skills/plan-review/SKILL.md"
verify "$STALE"
assert 'a stale golden fails' test "$LAST_EXIT" -ne 0
assert 'stale: names the file' grep -q 'antigravity/skills/flow-plan-review/SKILL.md' <<<"$LAST_OUTPUT"

# A Claude-only form the rewrite does not cover.
LEFT="$TMP_ROOT/leftover"
mkdir -p "$LEFT/plugins"
cp -r "$ROOT/plugins/flow" "$ROOT/plugins/toolkit" "$LEFT/plugins/"
cp -r "$ROOT/claude" "$LEFT/"
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
cp -r "$ROOT/plugins/flow" "$ROOT/plugins/toolkit" "$REFS/plugins/"
cp -r "$ROOT/claude" "$REFS/"
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
target=opencode
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

# A bare reference the rewrite does not cover: plain prose, no backticks.
BARE="$TMP_ROOT/bare"
mkdir -p "$BARE/plugins"
cp -r "$ROOT/plugins/flow" "$ROOT/plugins/toolkit" "$BARE/plugins/"
cp -r "$ROOT/claude" "$BARE/"
mkdir -p "$BARE/plugins/flow/skills/plan-review/references"
touch "$BARE/plugins/flow/skills/plan-review/references/x.md"
printf '\nSee references/x.md for details.\n' >>"$BARE/plugins/flow/skills/plan-review/SKILL.md"
verify "$BARE"
assert 'a bare support path fails' test "$LAST_EXIT" -ne 0
assert 'bare: names the file and line' grep -qE \
  'bare support path: opencode/skills/flow-plan-review/SKILL\.md:[0-9]+:.*references/x\.md' <<<"$LAST_OUTPUT"

echo "== agents that use engram =="
# A copy of the sources whose reviewer also asks for an engram tool.
MEM="$TMP_ROOT/mem"
mkdir -p "$MEM/plugins"
cp -r "$ROOT/plugins/flow" "$ROOT/plugins/toolkit" "$MEM/plugins/"
cp -r "$ROOT/claude" "$MEM/"
awk '/^tools: / { $0 = $0 ", mcp__engram__mem_search" } 1' "$ROOT/plugins/flow/agents/plan-reviewer.md" \
  >"$MEM/plugins/flow/agents/plan-reviewer.md"
MEM_OUT="$TMP_ROOT/mem-out"
LAST_OUTPUT=$(GEN_SOURCE="$MEM" GEN_REPO_PATH="$REPO_PATH" bash "$GEN" "$MEM_OUT" 2>&1)
LAST_EXIT=$?
assert 'mem: generator exits 0' test "$LAST_EXIT" -eq 0
[[ $LAST_EXIT -eq 0 ]] || printf '%s\n' "$LAST_OUTPUT"

echo "== the OpenCode verifier step =="
# A copy of the sources whose plan-review holds pair's real check step;
# flow-pair itself is generated in #09.
CHK="$TMP_ROOT/chk"
mkdir -p "$CHK/plugins"
cp -r "$ROOT/plugins/flow" "$ROOT/plugins/toolkit" "$CHK/plugins/"
cp -r "$ROOT/claude" "$CHK/"
{
  echo
  grep '^6\. \*\*Check\.\*\*' "$ROOT/plugins/flow/skills/pair/SKILL.md"
} >>"$CHK/plugins/flow/skills/plan-review/SKILL.md"
CHK_OUT="$TMP_ROOT/chk-out"
LAST_OUTPUT=$(GEN_SOURCE="$CHK" GEN_REPO_PATH="$REPO_PATH" bash "$GEN" "$CHK_OUT" 2>&1)
LAST_EXIT=$?
assert 'chk: generator exits 0' test "$LAST_EXIT" -eq 0
CHK_STEP=$(grep '^6\. \*\*Check\.\*\*' "$CHK_OUT/opencode/skills/flow-plan-review/SKILL.md")
# shellcheck disable=SC2016 # literal markdown backticks
assert 'chk: opencode check step is present' grep -qF 'invoke the `flow-verifier` agent' <<<"$CHK_STEP"

echo "== the role model map =="
# One map gives each reviewer agent its model per target (story 12).
# models MAP_JSON NAME: generate with that map into $TMP_ROOT/NAME.
models() {
  printf '%s\n' "$1" >"$TMP_ROOT/$2.json"
  LAST_OUTPUT=$(GEN_MODELS="$TMP_ROOT/$2.json" GEN_REPO_PATH="$REPO_PATH" bash "$GEN" "$TMP_ROOT/$2" 2>&1)
  LAST_EXIT=$?
}
models '{"reviewer": {"opencode": "ollama/qwen3", "antigravity": "pro"}}' local-reviewer
assert 'map: generator exits 0' test "$LAST_EXIT" -eq 0
[[ $LAST_EXIT -eq 0 ]] || printf '%s\n' "$LAST_OUTPUT"
for name in flow-plan-reviewer flow-verifier; do
  # The golden with the model line after mode: and nothing else changed.
  assert "map: OpenCode $name uses the mapped model" diff -u \
    <(awk '{ print } /^mode: subagent$/ { print "model: ollama/qwen3" }' "$GOLDEN/opencode/agents/$name.md") \
    "$TMP_ROOT/local-reviewer/opencode/agents/$name.md"
done
# A missing entry is an error, never a silent default.
models '{"reviewer": {}}' missing-entry
assert 'map: a missing entry fails' test "$LAST_EXIT" -ne 0
assert 'map: the error names the role' grep -qF 'reviewer' <<<"$LAST_OUTPUT"
assert 'map: the error names the target' grep -qF 'opencode' <<<"$LAST_OUTPUT"

if [[ $failures -gt 0 ]]; then
  echo "$failures case(s) failed"
  exit 1
fi
echo "All cases passed"
