#!/usr/bin/env bash
# install.sh tests: Claude Code target, retired plugins and argument errors. Run: bash scripts/tests/install-claude.test.sh
# Each case runs the real installer against a throwaway HOME with a stub
# `claude` CLI (setup in install-lib.sh).
set -u
# shellcheck source=scripts/tests/install-lib.sh
source "$(dirname "${BASH_SOURCE[0]}")/install-lib.sh"

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
# An existing directory: a missing one is dangling and gets replaced.
mkdir -p "$home/elsewhere"
git config --file "$home/.gitconfig" core.hooksPath "$home/elsewhere"
install "$home"
assert 'foreign hooksPath is left alone' \
  same "$(git config --file "$home/.gitconfig" core.hooksPath)" "$home/elsewhere"
assert 'foreign hooksPath is reported' rg -q 'skip: global core.hooksPath' <<<"$LAST_OUTPUT"

echo "== dangling core.hooksPath =="

home=$(sandbox dangling-hookspath)
git config --file "$home/.gitconfig" core.hooksPath "$home/moved-repo/git-hooks"
install "$home"
assert 'dangling hooksPath is pointed at the repo' \
  same "$(git config --file "$home/.gitconfig" core.hooksPath)" "$ROOT/git-hooks"
assert 'the replaced dangling value is reported' \
  rg -qF "replaced dangling core.hooksPath $home/moved-repo/git-hooks" <<<"$LAST_OUTPUT"

# A ~ value is dangling too: the startup warning expands it.
home=$(sandbox dangling-hookspath-tilde)
# shellcheck disable=SC2088 # the literal ~ is the value under test
git config --file "$home/.gitconfig" core.hooksPath '~/moved-repo/git-hooks'
install "$home"
assert 'a dangling ~ hooksPath is pointed at the repo' \
  same "$(git config --file "$home/.gitconfig" core.hooksPath)" "$ROOT/git-hooks"

home=$(sandbox dangling-hookspath-dry)
git config --file "$home/.gitconfig" core.hooksPath "$home/moved-repo/git-hooks"
install "$home" --dry-run
assert 'dry-run leaves a dangling hooksPath as it is' \
  same "$(git config --file "$home/.gitconfig" core.hooksPath)" "$home/moved-repo/git-hooks"
assert 'dry-run reports the hooksPath it would set' \
  rg -qF "[dry-run] git config --global core.hooksPath $ROOT/git-hooks" <<<"$LAST_OUTPUT"

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

finish_cases
