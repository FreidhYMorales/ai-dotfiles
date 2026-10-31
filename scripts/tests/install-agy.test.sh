#!/usr/bin/env bash
# install.sh tests: Antigravity links, rules and generated skills. Run: bash scripts/tests/install-agy.test.sh
# Each case runs the real installer against a throwaway HOME with a stub
# `claude` CLI (setup in install-lib.sh).
set -u
# shellcheck source=scripts/tests/install-lib.sh
source "$(dirname "${BASH_SOURCE[0]}")/install-lib.sh"

echo "== antigravity target =="

home=$(sandbox antigravity)
mkdir -p "$home/.gemini/config"
install "$home" --target antigravity
assert 'antigravity run succeeds' test "$LAST_EXIT" -eq 0
# agy 1.4.7 never reads antigravity-cli/AGENTS.md (sentinel check, story 01).
assert 'AGENTS.md is not linked where agy never reads it' test ! -e "$home/.gemini/antigravity-cli/AGENTS.md" -a ! -L "$home/.gemini/antigravity-cli/AGENTS.md"
assert 'AGENTS.md is linked for antigravity config' test -L "$home/.gemini/config/AGENTS.md"
assert 'output names the agy rules path' rg -qF "linked: $home/.gemini/config/AGENTS.md -> " <<<"$LAST_OUTPUT"
assert 'output names no unread agy rules path' test -z "$(rg -F "$home/.gemini/antigravity-cli/AGENTS.md" <<<"$LAST_OUTPUT")"
assert 'flow skills are linked for antigravity' test -L "$home/.gemini/antigravity-cli/skills/flow-plan"
assert 'toolkit skills are linked for antigravity' test -L "$home/.gemini/antigravity-cli/skills/toolkit-ship"
for skill in backlog story pair; do
  assert "Claude-only $skill is not linked for antigravity" test ! -e "$home/.gemini/antigravity-cli/skills/$skill" -a ! -L "$home/.gemini/antigravity-cli/skills/$skill"
done

echo "== antigravity gets the generated story loop =="

# An earlier run linked the raw judgment-day and work-unit-commits skills.
# Regression pin: green from the start, the lists are shared with opencode.
home=$(sandbox antigravity-story-loop)
agy_skills=$home/.gemini/antigravity-cli/skills
mkdir -p "$home/.gemini/config" "$agy_skills"
ln -s "$ROOT/plugins/toolkit/skills/judgment-day" "$agy_skills/judgment-day"
ln -s "$ROOT/plugins/toolkit/skills/work-unit-commits" "$agy_skills/work-unit-commits"
install "$home" --target antigravity
assert 'antigravity story loop run succeeds' test "$LAST_EXIT" -eq 0
for name in flow-backlog flow-story flow-pair toolkit-work-unit-commits; do
  assert "the agy $name skill is the generated one" \
    same "$(readlink "$agy_skills/$name")" "$home/build/agents/antigravity/skills/$name"
done
assert 'the agy verifier agent is the generated one' \
  same "$(readlink "$home/.gemini/config/agents/flow-verifier.md")" "$home/build/agents/antigravity/agents/flow-verifier.md"
for name in backlog story pair judgment-day work-unit-commits; do
  assert "no raw $name link is left for antigravity" test ! -e "$agy_skills/$name" -a ! -L "$agy_skills/$name"
done

echo "== antigravity gets every other skill generated =="

# An earlier run linked the raw plan and ship skills (story 30).
home=$(sandbox antigravity-remaining)
agy_skills=$home/.gemini/antigravity-cli/skills
mkdir -p "$home/.gemini/config" "$agy_skills"
ln -s "$ROOT/plugins/flow/skills/plan" "$agy_skills/plan"
ln -s "$ROOT/plugins/toolkit/skills/ship" "$agy_skills/ship"
install "$home" --target antigravity
assert 'antigravity remaining skills run succeeds' test "$LAST_EXIT" -eq 0
for name in $REMAINING; do
  assert "the agy $name skill is the generated one" \
    same "$(readlink "$agy_skills/$name")" "$home/build/agents/antigravity/skills/$name"
done
raw=$(find "$agy_skills" -maxdepth 1 -type l -lname "$ROOT/plugins/*")
assert 'no raw repo skill link is left for antigravity' same "$raw" ''
[[ -z $raw ]] || printf '%s\n' "$raw"

echo "== antigravity reads the generated rules =="

# An earlier run linked the raw rules (story 31).
home=$(sandbox antigravity-rules)
mkdir -p "$home/.gemini/config"
ln -s "$ROOT/AGENTS.md" "$home/.gemini/config/AGENTS.md"
install "$home" --target antigravity
assert 'antigravity rules run succeeds' test "$LAST_EXIT" -eq 0
assert 'the agy rules are the generated ones' \
  same "$(readlink "$home/.gemini/config/AGENTS.md")" "$home/build/agents/antigravity/AGENTS.md"
assert 'the raw agy rules link leaves no backup' \
  test -z "$(find "$home/.gemini/config" -maxdepth 1 -name 'AGENTS.md.bak-*')"

echo "== antigravity gets the generated plan review =="

home=$(sandbox antigravity-plan-review)
agy_skills=$home/.gemini/antigravity-cli/skills
mkdir -p "$home/.gemini/config" "$agy_skills"
ln -s "$ROOT/plugins/flow/skills/plan-review" "$agy_skills/plan-review"
install "$home" --target antigravity
assert 'antigravity plan review run succeeds' test "$LAST_EXIT" -eq 0
# agy reads custom subagents from ~/.gemini/config/agents/ (story 16).
assert 'the reviewer agent is the generated one' \
  diff -q "$ROOT/scripts/gen-agents/golden/antigravity/agents/flow-plan-reviewer.md" "$home/.gemini/config/agents/flow-plan-reviewer.md"
# shellcheck disable=SC2016 # literal markdown backticks
assert 'the skill delegates through invoke_subagent' \
  rg -qF 'Launch the `flow-plan-reviewer` subagent through `invoke_subagent`' "$agy_skills/flow-plan-review/SKILL.md"
assert 'the skill reads the rubric from this repo' \
  rg -qF "\`\"$ROOT/plugins/flow/agents/plan-reviewer.md\"\`" "$agy_skills/flow-plan-review/SKILL.md"
assert 'our raw plan-review link is removed' test ! -e "$agy_skills/plan-review" -a ! -L "$agy_skills/plan-review"

# A real plan-review dir is the user's: moved out of discovery into
# skills-backup (story 32), never removed.
home=$(sandbox antigravity-user-plan-review)
agy_skills=$home/.gemini/antigravity-cli/skills
mkdir -p "$home/.gemini/config" "$agy_skills/plan-review"
printf 'mine\n' >"$agy_skills/plan-review/SKILL.md"
install "$home" --target antigravity
assert 'antigravity run with a user plan-review succeeds' test "$LAST_EXIT" -eq 0
assert "the user's plan-review dir is kept in skills-backup" \
  same "$(cat "$home/.gemini/antigravity-cli/skills-backup/plan-review/SKILL.md" 2>/dev/null)" 'mine'
assert 'the generated skill sits beside it' test -f "$agy_skills/flow-plan-review/SKILL.md"

echo "== antigravity cleanup of the unread rules link =="

home=$(sandbox antigravity-rules-link)
mkdir -p "$home/.gemini/config" "$home/.gemini/antigravity-cli"
ln -s "$ROOT/AGENTS.md" "$home/.gemini/antigravity-cli/AGENTS.md"
install "$home" --target antigravity
assert 'a left-over repo link at antigravity-cli/AGENTS.md is removed' test ! -e "$home/.gemini/antigravity-cli/AGENTS.md" -a ! -L "$home/.gemini/antigravity-cli/AGENTS.md"

home=$(sandbox antigravity-rules-file)
mkdir -p "$home/.gemini/config" "$home/.gemini/antigravity-cli"
printf 'my own notes\n' >"$home/.gemini/antigravity-cli/AGENTS.md"
install "$home" --target antigravity
assert 'a user file at antigravity-cli/AGENTS.md is left alone' same "$(<"$home/.gemini/antigravity-cli/AGENTS.md")" 'my own notes'

echo "== antigravity moves a GEMINI.md that agy loads over the rules =="

home=$(sandbox antigravity-gemini-md)
mkdir -p "$home/.gemini/config"
printf 'gentle rules\n' >"$home/.gemini/GEMINI.md"
install "$home" --target antigravity
backups=("$home"/.gemini/GEMINI.md.bak-*)
assert 'GEMINI.md is no longer loaded' test ! -e "$home/.gemini/GEMINI.md"
assert 'exactly one GEMINI.md backup exists' test "${#backups[@]}" -eq 1 -a -f "${backups[0]}"
assert 'the backup keeps the content' same "$(<"${backups[0]}")" 'gentle rules'
assert 'output says how to restore it' rg -qF "restore: mv '${backups[0]}' '$home/.gemini/GEMINI.md'" <<<"$LAST_OUTPUT"

home=$(sandbox antigravity-no-gemini-md)
mkdir -p "$home/.gemini/config"
install "$home" --target antigravity
assert 'no GEMINI.md means no backup' test -z "$(find "$home/.gemini" -maxdepth 1 -name 'GEMINI.md.bak-*')"
assert 'no GEMINI.md means no restore hint' test -z "$(rg -F 'GEMINI.md' <<<"$LAST_OUTPUT")"

finish_cases
