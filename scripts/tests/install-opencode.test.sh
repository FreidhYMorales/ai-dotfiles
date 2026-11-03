#!/usr/bin/env bash
# install.sh tests: OpenCode target. Run: bash scripts/tests/install-opencode.test.sh
# Each case runs the real installer against a throwaway HOME with a stub
# `claude` CLI (setup in install-lib.sh).
set -u
# shellcheck source=scripts/tests/install-lib.sh
source "$(dirname "${BASH_SOURCE[0]}")/install-lib.sh"

echo "== opencode target =="

home=$(sandbox opencode)
install "$home" --target opencode
assert 'opencode run succeeds' test "$LAST_EXIT" -eq 0
assert 'AGENTS.md is linked for opencode' test -L "$home/.config/opencode/AGENTS.md"
assert 'flow skills are linked for opencode' test -L "$home/.config/opencode/skills/flow-plan"
assert 'no sdd skill is linked for opencode' test ! -e "$home/.config/opencode/skills/orchestrator" -a ! -L "$home/.config/opencode/skills/orchestrator"
assert 'toolkit skills are linked for opencode' test -L "$home/.config/opencode/skills/toolkit-ship"
for skill in backlog story pair; do
  assert "Claude-only $skill is not linked for opencode" test ! -e "$home/.config/opencode/skills/$skill" -a ! -L "$home/.config/opencode/skills/$skill"
done

echo "== opencode cleanup of Claude-only skills =="

home=$(sandbox opencode-cleanup)
skills=$home/.config/opencode/skills
mkdir -p "$skills" "$home/foreign/story"
ln -s "$ROOT/plugins/flow/skills/pair" "$skills/pair"
ln -s "$ROOT/plugins/flow/skills/backlog" "$skills/backlog"
ln -s "$home/foreign/story" "$skills/story"
install "$home" --target opencode
assert 'opencode cleanup run succeeds' test "$LAST_EXIT" -eq 0
assert 'a left-over repo link named pair is removed' test ! -e "$skills/pair" -a ! -L "$skills/pair"
assert 'a left-over repo link named backlog is removed' test ! -e "$skills/backlog" -a ! -L "$skills/backlog"
assert 'a foreign link named story is left alone' same "$(readlink "$skills/story")" "$home/foreign/story"
assert 'cleanup makes no backup of removed links' test -z "$(find "$skills" -name '*.bak-*')"

echo "== opencode engram registration =="

home=$(sandbox opencode-no-engram)
install "$home" --target opencode
assert 'opencode run without engram succeeds' test "$LAST_EXIT" -eq 0
assert 'missing opencode config says engram is not registered' \
  rg -qF 'engram is not registered in OpenCode' <<<"$LAST_OUTPUT"
assert 'missing opencode config names the manual step' rg -qF 'engram setup opencode' <<<"$LAST_OUTPUT"

home=$(sandbox opencode-engram-disabled)
mkdir -p "$home/.config/opencode"
printf '{"mcp": {"engram": {"type": "local", "command": ["engram", "mcp"], "enabled": false}}}\n' \
  >"$home/.config/opencode/opencode.json"
install "$home" --target opencode
assert 'opencode run with engram disabled succeeds' test "$LAST_EXIT" -eq 0
assert 'a disabled engram entry counts as not registered' \
  rg -qF 'engram is not registered in OpenCode; run: engram setup opencode' <<<"$LAST_OUTPUT"

home=$(sandbox opencode-engram)
config=$home/.config/opencode/opencode.json
mkdir -p "$home/.config/opencode"
printf '{"mcp": {"engram": {"type": "local", "command": ["engram", "mcp"], "enabled": true}}}\n' >"$config"
before=$(sha256sum <"$config")
install "$home" --target opencode
assert 'opencode run with engram succeeds' test "$LAST_EXIT" -eq 0
assert 'registered engram prints no engram warning' test -z "$(rg -F 'engram is not registered' <<<"$LAST_OUTPUT")"
assert 'the engram check leaves opencode.json unchanged' same "$(sha256sum <"$config")" "$before"

echo "== opencode links the toolkit plugin =="

# engram and herdr install their own plugin files in the same dir.
home=$(sandbox opencode-plugins)
plugins=$home/.config/opencode/plugins
mkdir -p "$plugins"
printf 'export default { id: "engram" }\n' >"$plugins/engram.ts"
printf 'export default { id: "herdr.opencode" }\n' >"$plugins/herdr-agent-state.js"
others=$(sha256sum "$plugins/engram.ts" "$plugins/herdr-agent-state.js")
install "$home" --target opencode
assert 'opencode plugins run succeeds' test "$LAST_EXIT" -eq 0
assert 'the toolkit plugin is linked to the repo' \
  same "$(readlink "$plugins/toolkit.ts")" "$ROOT/plugins/toolkit/opencode/toolkit.ts"
assert 'engram and herdr plugins are untouched' same "$(sha256sum "$plugins/engram.ts" "$plugins/herdr-agent-state.js")" "$others"
assert 'the plugins dir holds only the three plugins' \
  same "$(cd "$plugins" && printf '%s\n' * | paste -sd' ')" 'engram.ts herdr-agent-state.js toolkit.ts'

echo "== opencode gets the generated plan review =="

# An earlier run linked the raw plan-review skill; a user's dir sits beside it.
home=$(sandbox opencode-plan-review)
oc=$home/.config/opencode
mkdir -p "$oc/skills"
ln -s "$ROOT/plugins/flow/skills/plan-review" "$oc/skills/plan-review"
install "$home" --target opencode
assert 'opencode plan review run succeeds' test "$LAST_EXIT" -eq 0
assert 'the reviewer agent is the generated one' \
  diff -q "$ROOT/scripts/gen-agents/golden/opencode/agents/flow-plan-reviewer.md" "$oc/agents/flow-plan-reviewer.md"
assert 'the /flow-plan-review command is the generated one' \
  diff -q "$ROOT/scripts/gen-agents/golden/opencode/commands/flow-plan-review.md" "$oc/commands/flow-plan-review.md"
assert 'the skill reads the rubric from this repo' \
  rg -qF "\`\"$ROOT/plugins/flow/agents/plan-reviewer.md\"\`" "$oc/skills/flow-plan-review/SKILL.md"
assert 'the links point into the build dir' \
  same "$(readlink "$oc/agents/flow-plan-reviewer.md")" "$home/build/agents/opencode/agents/flow-plan-reviewer.md"
assert 'our raw plan-review link is removed' test ! -e "$oc/skills/plan-review" -a ! -L "$oc/skills/plan-review"
links=$(for f in "$oc/agents/flow-plan-reviewer.md" "$oc/commands/flow-plan-review.md" "$oc/skills/flow-plan-review"; do readlink "$f"; done)
install "$home" --target opencode
assert 'a second opencode run succeeds' test "$LAST_EXIT" -eq 0
assert 'a second run keeps the same links' \
  same "$(for f in "$oc/agents/flow-plan-reviewer.md" "$oc/commands/flow-plan-review.md" "$oc/skills/flow-plan-review"; do readlink "$f"; done)" "$links"
assert 'a second run makes no backups' test -z "$(find "$oc" -name '*.bak-*')"

echo "== opencode gets the generated story loop =="

# An earlier run linked the raw judgment-day and work-unit-commits skills.
home=$(sandbox opencode-story-loop)
oc=$home/.config/opencode
mkdir -p "$oc/skills"
ln -s "$ROOT/plugins/toolkit/skills/judgment-day" "$oc/skills/judgment-day"
ln -s "$ROOT/plugins/toolkit/skills/work-unit-commits" "$oc/skills/work-unit-commits"
install "$home" --target opencode
assert 'opencode story loop run succeeds' test "$LAST_EXIT" -eq 0
for name in flow-backlog flow-story flow-pair toolkit-work-unit-commits; do
  assert "the $name skill is the generated one" \
    same "$(readlink "$oc/skills/$name")" "$home/build/agents/opencode/skills/$name"
done
for name in flow-backlog flow-story flow-pair; do
  assert "the /$name command is the generated one" \
    diff -q "$ROOT/scripts/gen-agents/golden/opencode/commands/$name.md" "$oc/commands/$name.md"
done
assert 'the verifier agent reads the pair references from this repo' \
  rg -qF "\`\"$ROOT/plugins/flow/skills/pair/references/\"\`" "$oc/agents/flow-verifier.md"
for name in judgment-day work-unit-commits; do
  assert "our raw $name link is removed" test ! -e "$oc/skills/$name" -a ! -L "$oc/skills/$name"
done

echo "== opencode gets every other skill generated =="

# Every other flow and toolkit skill but judgment-day (story 30). An earlier
# run linked the raw plan and ship skills.
home=$(sandbox opencode-remaining)
oc=$home/.config/opencode
mkdir -p "$oc/skills"
ln -s "$ROOT/plugins/flow/skills/plan" "$oc/skills/plan"
ln -s "$ROOT/plugins/toolkit/skills/ship" "$oc/skills/ship"
install "$home" --target opencode
assert 'opencode remaining skills run succeeds' test "$LAST_EXIT" -eq 0
for name in $REMAINING; do
  assert "the $name skill is the generated one" \
    same "$(readlink "$oc/skills/$name")" "$home/build/agents/opencode/skills/$name"
done
for name in flow-plan flow-fill-gaps; do
  assert "the /$name command is the generated one" \
    diff -q "$ROOT/scripts/gen-agents/golden/opencode/commands/$name.md" "$oc/commands/$name.md"
done
# Every ported skill has a command (story 14).
for name in toolkit-work-unit-commits flow-research flow-handoff flow-next flow-idea flow-split \
  flow-integrate flow-foundation flow-bootstrap toolkit-ship toolkit-chained-pr toolkit-cli-tools \
  toolkit-cognitive-doc-design toolkit-comment-writer toolkit-delegate-local toolkit-go-testing \
  toolkit-skill-creator toolkit-skill-improver; do
  assert "the /$name command is the generated one" \
    same "$(readlink "$oc/commands/$name.md")" "$home/build/agents/opencode/commands/$name.md"
done
raw=$(find "$oc/skills" -maxdepth 1 -type l -lname "$ROOT/plugins/*")
assert 'no raw repo skill link is left for opencode' same "$raw" ''
[[ -z $raw ]] || printf '%s\n' "$raw"

echo "== opencode reads the generated rules =="

# An earlier run linked the raw rules (story 31).
home=$(sandbox opencode-rules)
oc=$home/.config/opencode
mkdir -p "$oc"
ln -s "$ROOT/AGENTS.md" "$oc/AGENTS.md"
install "$home" --target opencode
assert 'opencode rules run succeeds' test "$LAST_EXIT" -eq 0
assert 'the opencode rules are the generated ones' \
  same "$(readlink "$oc/AGENTS.md")" "$home/build/agents/opencode/AGENTS.md"
assert 'the raw rules link leaves no backup' test -z "$(find "$oc" -maxdepth 1 -name 'AGENTS.md.bak-*')"

echo "== a failed generation keeps the previous build =="

home=$(sandbox failed-generation)
install "$home" --target opencode
assert 'the first run builds' test "$LAST_EXIT" -eq 0
build_before=$(readlink "$home/build/agents")
# GEN_SOURCE reaches the generator; a missing source makes it fail.
GEN_SOURCE="$home/no-source" install "$home" --target opencode
assert 'a failed generation fails the run' test "$LAST_EXIT" -ne 0
assert 'the error names the generator' rg -qF 'gen-agents' <<<"$LAST_OUTPUT"
assert 'the build still points at the previous generation' same "$(readlink "$home/build/agents")" "$build_before"
assert 'the previous generation is intact' \
  diff -q "$ROOT/scripts/gen-agents/golden/opencode/agents/flow-plan-reviewer.md" "$home/build/agents/opencode/agents/flow-plan-reviewer.md"
assert 'no partial generation is left behind' \
  same "$(cd "$home/build" && printf '%s\n' * | paste -sd' ')" "agents $build_before"

echo "== opencode prunes links into a build dir outside the repo =="

# The sandbox's AI_BUILD_DIR ($home/build/agents) is outside the repo.
home=$(sandbox external-build-prune)
skills=$home/.config/opencode/skills
mkdir -p "$skills"
ln -s "$home/build/agents/opencode/skills/flow-gone" "$skills/flow-gone"
ln -s "$home/gone" "$skills/foreign-gone"
install "$home" --target opencode
assert 'external build prune run succeeds' test "$LAST_EXIT" -eq 0
assert 'a dangling link into the external build dir is removed' test ! -e "$skills/flow-gone" -a ! -L "$skills/flow-gone"
assert 'the removal is reported' rg -qF "pruned broken link: $skills/flow-gone" <<<"$LAST_OUTPUT"
assert 'a dangling link outside the repo and the build dir stays' same "$(readlink "$skills/foreign-gone")" "$home/gone"

finish_cases
