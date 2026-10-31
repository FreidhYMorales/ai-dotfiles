#!/usr/bin/env bash
# install.sh tests: Antigravity skill sweeps, engram and hooks. Run: bash scripts/tests/install-agy-skills.test.sh
# Each case runs the real installer against a throwaway HOME with a stub
# `claude` CLI (setup in install-lib.sh).
set -u
# shellcheck source=scripts/tests/install-lib.sh
source "$(dirname "${BASH_SOURCE[0]}")/install-lib.sh"

echo "== antigravity moves skill backups out of discovery =="

# agy 1.4.7 discovers a skill in a *.bak-* dir by its name: (story 02 check),
# but never looks in antigravity-cli/skills-backup/.
home=$(sandbox antigravity-skill-backups)
skills=$home/.gemini/antigravity-cli/skills
mkdir -p "$home/.gemini/config" "$skills/judgment-day.bak-20261023-170049"
printf 'gentle judgment day\n' >"$skills/judgment-day.bak-20261023-170049/SKILL.md"
install "$home" --target antigravity
moved=$home/.gemini/antigravity-cli/skills-backup/judgment-day.bak-20261023-170049
assert 'the skill backup leaves the discovery dir' test ! -e "$skills/judgment-day.bak-20261023-170049"
assert 'the skill backup keeps its content' same "$(<"$moved/SKILL.md")" 'gentle judgment day'
assert 'output names the skill backup move' rg -qF "moved skill backup: $skills/judgment-day.bak-20261023-170049 -> $moved" <<<"$LAST_OUTPUT"

# agy discovers all three skills dirs (story 02), so a *.bak-* dir in the other
# two shadows ours too (story 35).
home=$(sandbox antigravity-skill-backups-all-dirs)
kept=$home/.gemini/antigravity-cli/skills-backup
mkdir -p "$home/.gemini/skills/branch-pr.bak-1" "$home/.gemini/config/skills/issue-creation.bak-2"
printf 'from gemini skills\n' >"$home/.gemini/skills/branch-pr.bak-1/SKILL.md"
printf 'from config skills\n' >"$home/.gemini/config/skills/issue-creation.bak-2/SKILL.md"
install "$home" --target antigravity
assert 'a skill backup in ~/.gemini/skills leaves discovery' test ! -e "$home/.gemini/skills/branch-pr.bak-1"
assert 'a skill backup in ~/.gemini/config/skills leaves discovery' test ! -e "$home/.gemini/config/skills/issue-creation.bak-2"
assert 'the ~/.gemini/skills backup is kept in skills-backup' \
  same "$(cat "$kept/branch-pr.bak-1/SKILL.md" 2>/dev/null)" 'from gemini skills'
assert 'the ~/.gemini/config/skills backup is kept in skills-backup' \
  same "$(cat "$kept/issue-creation.bak-2/SKILL.md" 2>/dev/null)" 'from config skills'

home=$(sandbox antigravity-skill-backup-clash)
skills=$home/.gemini/antigravity-cli/skills
kept=$home/.gemini/antigravity-cli/skills-backup
mkdir -p "$home/.gemini/config" "$skills/work-unit-commits.bak-1" "$kept/work-unit-commits.bak-1"
printf 'first copy\n' >"$kept/work-unit-commits.bak-1/SKILL.md"
printf 'second copy\n' >"$skills/work-unit-commits.bak-1/SKILL.md"
install "$home" --target antigravity
copies=("$kept"/work-unit-commits.bak-1*)
assert 'a taken backup name is not overwritten' same "$(<"$kept/work-unit-commits.bak-1/SKILL.md")" 'first copy'
assert 'the clashing backup is not nested inside the taken one' test ! -e "$kept/work-unit-commits.bak-1/work-unit-commits.bak-1"
assert 'the clashing backup sits next to it' test "${#copies[@]}" -eq 2
assert 'the clashing backup keeps its content' rg -qx 'second copy' "${copies[@]/%//SKILL.md}"
assert 'the clashing backup leaves the discovery dir' test ! -e "$skills/work-unit-commits.bak-1"

# A real gentle-ai dir named like a repo skill is renamed to *.bak-* by the
# link step itself; that backup must leave discovery in the same run.
home=$(sandbox antigravity-skill-same-run)
skills=$home/.gemini/antigravity-cli/skills
kept=$home/.gemini/antigravity-cli/skills-backup
mkdir -p "$home/.gemini/config" "$skills/toolkit-ship"
printf 'gentle original\n' >"$skills/toolkit-ship/SKILL.md"
install "$home" --target antigravity
assert 'one install leaves no skill backup in discovery' test -z "$(find "$skills" -maxdepth 1 -name '*.bak-*')"
assert 'the renamed original is in skills-backup' rg -qx 'gentle original' "$kept" -g 'SKILL.md'
install "$home" --target antigravity
assert 'a second install moves no skill backup' test -z "$(rg -F 'moved skill backup:' <<<"$LAST_OUTPUT")"

home=$(sandbox antigravity-cleanup)
skills=$home/.gemini/antigravity-cli/skills
mkdir -p "$skills/pair"
printf 'mine\n' >"$skills/pair/SKILL.md"
install "$home" --target antigravity
assert 'antigravity cleanup run succeeds' test "$LAST_EXIT" -eq 0
# A real dir named like a repo skill leaves discovery but is never deleted
# (story 32).
assert 'a real directory named pair is moved to skills-backup' \
  same "$(cat "$home/.gemini/antigravity-cli/skills-backup/pair/SKILL.md" 2>/dev/null)" 'mine'

echo "== antigravity moves gentle-ai's same-named and sdd skills aside =="

# gentle-ai copies with repo skill names and its retired sdd-* skills in all
# three discovery dirs (story 32).
home=$(sandbox antigravity-gentle-skills)
kept=$home/.gemini/antigravity-cli/skills-backup
gentle_wuc=$home/.gemini/skills/work-unit-commits
gentle_jd=$home/.gemini/config/skills/judgment-day
gentle_sdd=$home/.gemini/antigravity-cli/skills/sdd-apply
mkdir -p "$gentle_wuc" "$gentle_jd" "$gentle_sdd"
printf 'gentle wuc\n' >"$gentle_wuc/SKILL.md"
printf 'gentle jd\n' >"$gentle_jd/SKILL.md"
printf 'gentle sdd\n' >"$gentle_sdd/SKILL.md"
install "$home" --target antigravity
assert 'antigravity gentle skills run succeeds' test "$LAST_EXIT" -eq 0
assert 'work-unit-commits leaves ~/.gemini/skills' test ! -e "$gentle_wuc"
assert 'judgment-day leaves ~/.gemini/config/skills' test ! -e "$gentle_jd"
assert 'sdd-apply leaves antigravity-cli/skills' test ! -e "$gentle_sdd"
assert 'work-unit-commits keeps its content' same "$(cat "$kept/work-unit-commits/SKILL.md" 2>/dev/null)" 'gentle wuc'
assert 'judgment-day keeps its content' same "$(cat "$kept/judgment-day/SKILL.md" 2>/dev/null)" 'gentle jd'
assert 'sdd-apply keeps its content' same "$(cat "$kept/sdd-apply/SKILL.md" 2>/dev/null)" 'gentle sdd'
assert 'output names the work-unit-commits move' \
  rg -qF "moved gentle-ai skill: $gentle_wuc -> $kept/work-unit-commits" <<<"$LAST_OUTPUT"
assert 'output names the judgment-day move' \
  rg -qF "moved gentle-ai skill: $gentle_jd -> $kept/judgment-day" <<<"$LAST_OUTPUT"
assert 'output names the sdd-apply move' \
  rg -qF "moved gentle-ai skill: $gentle_sdd -> $kept/sdd-apply" <<<"$LAST_OUTPUT"

# Other gentle-ai skills and the installer's links stay.
home=$(sandbox antigravity-gentle-others)
gentle=$home/.gemini/skills
agy_skills=$home/.gemini/antigravity-cli/skills
mkdir -p "$home/.gemini/config" "$gentle/branch-pr" "$gentle/_shared"
printf 'gentle branch-pr\n' >"$gentle/branch-pr/SKILL.md"
printf 'gentle shared\n' >"$gentle/_shared/SKILL.md"
install "$home" --target antigravity
assert 'antigravity gentle others run succeeds' test "$LAST_EXIT" -eq 0
assert 'branch-pr stays' same "$(cat "$gentle/branch-pr/SKILL.md" 2>/dev/null)" 'gentle branch-pr'
assert '_shared stays' same "$(cat "$gentle/_shared/SKILL.md" 2>/dev/null)" 'gentle shared'
assert 'the generated toolkit-ship link stays' \
  same "$(readlink "$agy_skills/toolkit-ship")" "$home/build/agents/antigravity/skills/toolkit-ship"
assert 'no other skill is moved' test -z "$(rg -F 'moved gentle-ai skill:' <<<"$LAST_OUTPUT")"

# A taken backup name and the same name in two discovery dirs.
home=$(sandbox antigravity-gentle-clash)
kept=$home/.gemini/antigravity-cli/skills-backup
mkdir -p "$home/.gemini/config" "$kept/work-unit-commits" "$home/.gemini/skills/work-unit-commits" \
  "$home/.gemini/skills/sdd-spec" "$home/.gemini/antigravity-cli/skills/sdd-spec"
printf 'old backup\n' >"$kept/work-unit-commits/SKILL.md"
printf 'new copy\n' >"$home/.gemini/skills/work-unit-commits/SKILL.md"
printf 'spec from gemini\n' >"$home/.gemini/skills/sdd-spec/SKILL.md"
printf 'spec from agy\n' >"$home/.gemini/antigravity-cli/skills/sdd-spec/SKILL.md"
install "$home" --target antigravity
assert 'antigravity gentle clash run succeeds' test "$LAST_EXIT" -eq 0
assert 'the old backup is not overwritten' same "$(cat "$kept/work-unit-commits/SKILL.md" 2>/dev/null)" 'old backup'
assert 'the new copy is kept beside it' same "$(cat "$kept/work-unit-commits.1/SKILL.md" 2>/dev/null)" 'new copy'
assert 'the gemini sdd-spec is kept' rg -qx 'spec from gemini' "$kept" -g 'SKILL.md'
assert 'the agy sdd-spec is kept' rg -qx 'spec from agy' "$kept" -g 'SKILL.md'
install "$home" --target antigravity
assert 'a second install moves no gentle-ai skill' test -z "$(rg -F 'moved gentle-ai skill:' <<<"$LAST_OUTPUT")"

echo "== antigravity engram registration =="

home=$(sandbox antigravity-no-engram)
mkdir -p "$home/.gemini/config"
printf 'NAME     TYPE   STATUS   COMMAND/URL\ncontext7 stdio  enabled  npx context7-mcp\n' >"$home/state/agy-mcp-list"
install "$home" --target antigravity
assert 'antigravity run without engram succeeds' test "$LAST_EXIT" -eq 0
assert 'agy without engram says engram is not registered' \
  rg -qF 'engram is not registered in Antigravity' <<<"$LAST_OUTPUT"
assert 'agy without engram names the manual step' rg -qF 'engram setup antigravity-cli' <<<"$LAST_OUTPUT"

# No agy at all: drop the stub and every PATH dir that has a real one.
home=$(sandbox antigravity-no-agy)
mkdir -p "$home/.gemini/config"
rm "$home/bin/agy"
no_agy_path=$(tr ':' '\n' <<<"$PATH" | while IFS= read -r dir; do [[ -x $dir/agy ]] || printf '%s\n' "$dir"; done | paste -sd:)
PATH=$no_agy_path install "$home" --target antigravity
assert 'antigravity run without agy succeeds' test "$LAST_EXIT" -eq 0
assert 'without agy the engram check says it cannot check' \
  rg -qF 'engram cannot be checked in Antigravity (agy not found)' <<<"$LAST_OUTPUT"
assert 'without agy the output names the manual step' rg -qF 'engram setup antigravity-cli' <<<"$LAST_OUTPUT"
assert 'without agy the output does not claim engram is unregistered' \
  test -z "$(rg -F 'engram is not registered in Antigravity' <<<"$LAST_OUTPUT")"

# The sandbox's default `agy mcp list` lists engram.
home=$(sandbox antigravity-engram)
mkdir -p "$home/.gemini/config"
install "$home" --target antigravity
assert 'antigravity run with engram succeeds' test "$LAST_EXIT" -eq 0
assert 'agy with engram prints no engram warning' \
  test -z "$(rg -F -e 'engram is not registered' -e 'engram cannot be checked' <<<"$LAST_OUTPUT")"

echo "== antigravity merges the toolkit hooks =="

# herdr writes its own key into the same hooks.json (no trailing newline).
home=$(sandbox antigravity-hooks)
hooks=$home/.gemini/config/hooks.json
mkdir -p "$home/.gemini/config"
printf '%s' '{
  "herdr": {
    "PreInvocation": [
      {
        "command": "bash '\''/x/herdr-agent-state.sh'\'' session",
        "timeout": 10,
        "type": "command"
      }
    ]
  }
}' >"$hooks"
herdr_before=$(jq -S -c .herdr "$hooks")
install "$home" --target antigravity
assert 'antigravity hooks run succeeds' test "$LAST_EXIT" -eq 0
assert 'the herdr key keeps its value' same "$(jq -S -c .herdr "$hooks")" "$herdr_before"
# shellcheck disable=SC2016 # $cmd is a jq variable, not a shell one.
assert 'a toolkit key runs the agy adapter on run_command' json_true "$hooks" --arg cmd "bash '$ROOT/plugins/toolkit/hooks/agy/prefer-modern-cli.sh'" \
  '.toolkit.PreToolUse == [{matcher: "run_command", hooks: [{type: "command", command: $cmd}]}]'
# Stop handlers are a flat list (no matcher); the 330 s timeout covers
# require-check's 300 s make check.
# shellcheck disable=SC2016 # $stop is a jq variable, not a shell one.
assert 'the toolkit key holds the Stop gate' json_true "$hooks" \
  --arg stop "bash '$ROOT/plugins/toolkit/hooks/agy/require-check.sh'" \
  '.toolkit.Stop == [{type: "command", command: $stop, timeout: 330}]'
# SessionStart is a flat list too; 15 s covers the three hooks' 5 + 2 + 5 s.
# shellcheck disable=SC2016 # $pre, $stop and $start are jq variables, not shell ones.
assert 'the toolkit key holds exactly the PreToolUse, Stop and SessionStart hooks' json_true "$hooks" \
  --arg pre "bash '$ROOT/plugins/toolkit/hooks/agy/prefer-modern-cli.sh'" \
  --arg stop "bash '$ROOT/plugins/toolkit/hooks/agy/require-check.sh'" \
  --arg start "bash '$ROOT/plugins/toolkit/hooks/agy/session-start.sh'" \
  '.toolkit == {PreToolUse: [{matcher: "run_command", hooks: [{type: "command", command: $pre}]}],
    Stop: [{type: "command", command: $stop, timeout: 330}],
    SessionStart: [{type: "command", command: $start, timeout: 15}]}'
assert 'hooks.json has only the herdr and toolkit keys' same "$(jq -c 'keys' "$hooks")" '["herdr","toolkit"]'
merged=$(sha256sum <"$hooks")
install "$home" --target antigravity
assert 'a second install leaves hooks.json unchanged' same "$(sha256sum <"$hooks")" "$merged"

home=$(sandbox antigravity-no-hooks)
hooks=$home/.gemini/config/hooks.json
mkdir -p "$home/.gemini/config"
install "$home" --target antigravity
assert 'antigravity run without hooks.json succeeds' test "$LAST_EXIT" -eq 0
assert 'a missing hooks.json is created with only the toolkit key' same "$(jq -c 'keys' "$hooks")" '["toolkit"]'
assert 'the created toolkit key gates run_command' json_true "$hooks" '.toolkit.PreToolUse[0].matcher == "run_command"'

finish_cases
