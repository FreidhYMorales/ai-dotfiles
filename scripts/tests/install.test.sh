#!/usr/bin/env bash
# Idempotency tests for install.sh. Run: bash scripts/tests/install.test.sh
# Each case runs the real installer against a throwaway HOME with a stub
# `claude` CLI, then checks that a second run changes nothing.
set -u

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
INSTALL="$ROOT/install.sh"
failures=0
TMP_ROOT=$(mktemp -d)
trap 'rm -rf "$TMP_ROOT"' EXIT

# sandbox NAME: create an isolated HOME with a stateful `claude` stub; print its path.
sandbox() {
  local home="$TMP_ROOT/$1"
  mkdir -p "$home/bin" "$home/state"
  cat >"$home/bin/claude" <<'EOF'
#!/usr/bin/env bash
state=$FAKE_CLAUDE_STATE
printf '%s\n' "$*" >>"$state/calls"
case "$1 $2 ${3:-}" in
"plugin marketplace list") [[ -f $state/marketplace ]] && echo "  ❯ ai-dotfiles" ;;
"plugin marketplace add") touch "$state/marketplace" ;;
"plugin list "*) cat "$state/plugins" 2>/dev/null ;;
"plugin install "*) printf '%s\n' "$3" >>"$state/plugins" ;;
"plugin uninstall "*) rg -vxF "$3" "$state/plugins" >"$state/plugins.new"; mv "$state/plugins.new" "$state/plugins" ;;
esac
exit 0
EOF
  cat >"$home/bin/systemctl" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$*" >>"$FAKE_CLAUDE_STATE/systemctl"
EOF
  # `agy mcp list` prints state/agy-mcp-list; engram is registered by default.
  printf 'NAME    TYPE   STATUS   COMMAND/URL\nengram  stdio  enabled  engram mcp --tools=agent\n' \
    >"$home/state/agy-mcp-list"
  cat >"$home/bin/agy" <<'EOF'
#!/usr/bin/env bash
[[ "$*" == "mcp list" ]] && cat "$FAKE_CLAUDE_STATE/agy-mcp-list"
exit 0
EOF
  chmod +x "$home/bin/claude" "$home/bin/systemctl" "$home/bin/agy"
  printf '%s\n' "$home"
}

# install HOME [ARGS...]: run install.sh inside the sandbox; output in $LAST_OUTPUT.
LAST_OUTPUT=""
LAST_EXIT=0
install() {
  local home=$1
  shift
  LAST_OUTPUT=$(env -u XDG_BIN_HOME -u XDG_CONFIG_HOME HOME="$home" CLAUDE_CONFIG_DIR="$home/.claude" \
    GIT_CONFIG_GLOBAL="$home/.gitconfig" GIT_CONFIG_NOSYSTEM=1 \
    FAKE_CLAUDE_STATE="$home/state" PATH="$home/bin:$PATH" \
    bash "$INSTALL" "$@" 2>&1)
  LAST_EXIT=$?
}

# snapshot HOME: every file under the sandbox's ~/.claude and ~/.gitconfig,
# with its type, link target and content hash.
snapshot() {
  local home=$1 path
  while IFS= read -r path; do
    if [[ -L $path ]]; then
      printf 'link %s -> %s\n' "${path#"$home"}" "$(readlink "$path")"
    else
      printf 'file %s %s\n' "${path#"$home"}" "$(sha256sum <"$path" | cut -d' ' -f1)"
    fi
  done < <(find "$home/.claude" "$home/.gitconfig" "$home/.local/bin" "$home/.config/systemd" \
    \( -type f -o -type l \) 2>/dev/null | sort)
}

# assert LABEL CONDITION...: run a test command and record PASS/FAIL.
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

same() { [[ $1 == "$2" ]]; }
# json_true FILE [JQ_ARGS...] FILTER: FILTER evaluates to true on FILE.
json_true() {
  local file=$1
  shift
  jq -e "$@" "$file" >/dev/null 2>&1
}
backups() { find "$1/.claude" -name '*.bak-*' 2>/dev/null | wc -l; }
calls_since() { tail -n +"$(($2 + 1))" "$1/state/calls"; }
call_count() { wc -l <"$1/state/calls"; }

echo "== fresh HOME =="

home=$(sandbox fresh)
install "$home"
assert 'first run succeeds' test "$LAST_EXIT" -eq 0
assert 'CLAUDE.md is linked to the repo' same "$(readlink "$home/.claude/CLAUDE.md")" "$ROOT/claude/CLAUDE.md"
assert 'output style is linked' test -L "$home/.claude/output-styles/gentleman.md"
assert 'status line script is linked' same "$(readlink "$home/.claude/statusline.sh")" "$ROOT/claude/statusline.sh"
assert 'settings point the status line at it' json_true "$home/.claude/settings.json" '.statusLine.command == "~/.claude/statusline.sh"'
assert 'settings.json is created' test -f "$home/.claude/settings.json"
assert 'git hooksPath points to the repo' \
  same "$(git config --file "$home/.gitconfig" core.hooksPath)" "$ROOT/git-hooks"
assert 'backup timer unit is linked' \
  same "$(readlink "$home/.config/systemd/user/engram-backup.timer")" "$ROOT/systemd/engram-backup.timer"
assert 'backup service unit is linked' test -L "$home/.config/systemd/user/engram-backup.service"
assert 'backup timers are not enabled before engram-backup is configured' \
  test -z "$(rg 'enable .*engram-backup' "$home/state/systemctl" 2>/dev/null)"
assert 'upstream-watch timer is linked' test -L "$home/.config/systemd/user/upstream-watch.timer"
assert 'upstream-watch timer is enabled' \
  rg -qxF -- '--user enable --now upstream-watch.timer' "$home/state/systemctl"
assert 'unconfigured backup explains the next step' rg -q 'engram-backup --init' <<<"$LAST_OUTPUT"
assert 'ai-update is linked into ~/.local/bin' \
  same "$(readlink "$home/.local/bin/ai-update")" "$ROOT/bin/ai-update"
assert 'missing ~/.local/bin on PATH is reported' rg -q 'not on PATH' <<<"$LAST_OUTPUT"
assert 'marketplace is added' test -f "$home/state/marketplace"
assert 'all shipped plugins are installed, sdd is not' same "$(sort "$home/state/plugins" | tr '\n' ' ')" \
  'flow@ai-dotfiles look@ai-dotfiles toolkit@ai-dotfiles '
assert 'a fresh run uninstalls nothing' test -z "$(rg 'plugin uninstall' "$home/state/calls")"

first=$(snapshot "$home")
before=$(call_count "$home")
install "$home"
assert 'second run succeeds' test "$LAST_EXIT" -eq 0
assert 'second run changes no file' same "$(snapshot "$home")" "$first"
assert 'second run makes no backup' same "$(backups "$home")" 0
assert 'second run does not re-add the marketplace' \
  test -z "$(calls_since "$home" "$before" | rg 'marketplace add')"
assert 'second run updates instead of installing' \
  test -z "$(calls_since "$home" "$before" | rg 'plugin install')"

echo "== existing user config =="

home=$(sandbox existing)
mkdir -p "$home/.claude"
printf '# my own notes\n' >"$home/.claude/CLAUDE.md"
jq -n '{model: "opus", permissions: {deny: ["Read(./secret.txt)"]}}' >"$home/.claude/settings.json"
chmod 640 "$home/.claude/settings.json"
inode_before=$(stat -c %i "$home/.claude/settings.json")
install "$home"
assert 'run with existing config succeeds' test "$LAST_EXIT" -eq 0
# A new inode means the merge was written aside and renamed into place, so an
# interrupted run can never leave a truncated settings.json behind.
assert 'settings.json is replaced atomically' \
  test "$(stat -c %i "$home/.claude/settings.json")" != "$inode_before"
assert 'replacement keeps the file mode' same "$(stat -c %a "$home/.claude/settings.json")" 640
assert 'no temporary file is left behind' test -z "$(find "$home/.claude" -name '*.tmp*')"
assert 'existing CLAUDE.md is backed up' \
  rg -q '^# my own notes$' "$(find "$home/.claude" -name 'CLAUDE.md.bak-*' | head -n1)"
settings=$home/.claude/settings.json
assert 'user settings keys are kept' json_true "$settings" '.model == "opus"'
assert 'user deny rules come first, in order' \
  json_true "$settings" '.permissions.deny[0] == "Read(./secret.txt)"'
# shellcheck disable=SC2016 # $repo is a jq variable, not a shell one.
assert 'repo deny rules are merged in repo order' \
  json_true "$settings" --slurpfile repo "$ROOT/claude/settings.json" \
  '.permissions.deny[1:] == $repo[0].permissions.deny'

first=$(snapshot "$home")
first_backups=$(backups "$home")
install "$home"
assert 'second run over merged config changes no file' same "$(snapshot "$home")" "$first"
assert 'second run over merged config makes no new backup' same "$(backups "$home")" "$first_backups"

echo "== existing core.hooksPath =="

home=$(sandbox hookspath)
git config --file "$home/.gitconfig" core.hooksPath /elsewhere
install "$home"
assert 'foreign hooksPath is left alone' \
  same "$(git config --file "$home/.gitconfig" core.hooksPath)" /elsewhere
assert 'foreign hooksPath is reported' rg -q 'skip: global core.hooksPath' <<<"$LAST_OUTPUT"

echo "== configured backup =="

home=$(sandbox backup-ready)
mkdir -p "$home/.config/restic"
printf 'ENGRAM_BACKUP_REPOS="/tmp/x"\n' >"$home/.config/restic/engram.env"
install "$home"
assert 'configured backup enables the timer' \
  rg -qxF -- '--user enable --now engram-backup.timer' "$home/state/systemctl"
assert 'units are reloaded before enabling' rg -qxF -- '--user daemon-reload' "$home/state/systemctl"
assert 'configured backup enables the weekly verify timer' \
  rg -qxF -- '--user enable --now engram-backup-verify.timer' "$home/state/systemctl"
assert 'verify timer unit is linked' test -L "$home/.config/systemd/user/engram-backup-verify.timer"

echo "== dry run =="

home=$(sandbox dry)
install "$home" --dry-run
assert 'dry run succeeds' test "$LAST_EXIT" -eq 0
assert 'dry run writes nothing' test -z "$(snapshot "$home")"
assert 'dry run calls no mutating claude command' \
  test -z "$(rg 'marketplace add|plugin (install|update)' "$home/state/calls" 2>/dev/null)"

echo "== opencode target =="

home=$(sandbox opencode)
install "$home" --target opencode
assert 'opencode run succeeds' test "$LAST_EXIT" -eq 0
assert 'AGENTS.md is linked for opencode' test -L "$home/.config/opencode/AGENTS.md"
assert 'flow skills are linked for opencode' test -L "$home/.config/opencode/skills/plan"
assert 'no sdd skill is linked for opencode' test ! -e "$home/.config/opencode/skills/orchestrator" -a ! -L "$home/.config/opencode/skills/orchestrator"
assert 'toolkit skills are linked for opencode' test -L "$home/.config/opencode/skills/judgment-day"
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
assert 'flow skills are linked for antigravity' test -L "$home/.gemini/antigravity-cli/skills/plan"
assert 'toolkit skills are linked for antigravity' test -L "$home/.gemini/antigravity-cli/skills/judgment-day"
for skill in backlog story pair; do
  assert "Claude-only $skill is not linked for antigravity" test ! -e "$home/.gemini/antigravity-cli/skills/$skill" -a ! -L "$home/.gemini/antigravity-cli/skills/$skill"
done

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
mkdir -p "$home/.gemini/config" "$skills/judgment-day"
printf 'gentle original\n' >"$skills/judgment-day/SKILL.md"
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
assert 'a real directory named pair is left alone' test -d "$skills/pair" -a ! -L "$skills/pair" -a -f "$skills/pair/SKILL.md"

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
  '.toolkit == {PreToolUse: [{matcher: "run_command", hooks: [{type: "command", command: $cmd}]}]}'
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

echo "== retired sdd plugin =="

home=$(sandbox sdd-installed)
printf '%s\n' flow@ai-dotfiles sdd@ai-dotfiles >"$home/state/plugins"
touch "$home/state/marketplace"
install "$home" --target claude
assert 'run over an installed sdd succeeds' test "$LAST_EXIT" -eq 0
assert 'installed sdd is uninstalled' rg -qxF 'plugin uninstall sdd@ai-dotfiles' "$home/state/calls"

# Links into the repo whose target is gone (a retired plugin's skills, an old
# script or unit) are pruned in every place the installer links to.
home=$(sandbox prune)
broken=(
  "$home/.claude/output-styles/retired.md:$ROOT/claude/output-styles/retired.md"
  "$home/.config/opencode/skills/retired-skill:$ROOT/plugins/retired/skills/retired-skill"
  "$home/.gemini/antigravity-cli/skills/retired-skill:$ROOT/plugins/retired/skills/retired-skill"
  "$home/.local/bin/retired-tool:$ROOT/bin/retired-tool"
  "$home/.config/systemd/user/retired.service:$ROOT/systemd/retired.service"
)
for pair in "${broken[@]}"; do
  mkdir -p "$(dirname "${pair%%:*}")"
  ln -s "${pair#*:}" "${pair%%:*}"
done
install "$home" --target all
assert 'prune run succeeds' test "$LAST_EXIT" -eq 0
for pair in "${broken[@]}"; do
  link=${pair%%:*}
  assert "broken repo link ${link#"$home"/} is pruned" test ! -L "$link"
done

# The prune touches only broken links into the repo.
home=$(sandbox prune-keeps)
skills=$home/.config/opencode/skills
mkdir -p "$skills" "$home/.local/bin"
ln -s "$ROOT/README.md" "$skills/resolving"
ln -s "$home/gone" "$skills/foreign"
printf 'mine\n' >"$home/.local/bin/notes"
install "$home" --target opencode
assert 'prune-keeps run succeeds' test "$LAST_EXIT" -eq 0
assert 'a resolving repo link stays' same "$(readlink "$skills/resolving")" "$ROOT/README.md"
assert 'a broken foreign link stays' same "$(readlink "$skills/foreign")" "$home/gone"
assert 'a real file stays' same "$(<"$home/.local/bin/notes")" 'mine'

echo "== target without a value =="

home=$(sandbox notarget)
install "$home" --target
assert 'missing target value fails' test "$LAST_EXIT" -ne 0
assert 'missing target value explains why' rg -q -- '--target needs a value' <<<"$LAST_OUTPUT"

echo
if [[ $failures -gt 0 ]]; then
  echo "$failures case(s) failed"
  exit 1
fi
echo "All cases passed"
