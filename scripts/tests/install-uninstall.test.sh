#!/usr/bin/env bash
# install.sh tests: --uninstall removes only what the installer put in place (story 16). Run: bash scripts/tests/install-uninstall.test.sh
# Each case runs the real installer against a throwaway HOME with stub
# `claude`, `systemctl` and `agy` CLIs (setup in install-lib.sh).
set -u
# shellcheck source=scripts/tests/install-lib.sh
source "$(dirname "${BASH_SOURCE[0]}")/install-lib.sh"

# our_links HOME: every symlink under HOME (the build dir aside) whose target
# is inside the repo or the sandbox build dir, one per line, sorted.
our_links() {
  local home=$1 path target
  while IFS= read -r path; do
    target=$(readlink "$path")
    [[ $target == "$ROOT"/* || $target == "$home/build/agents"/* ]] && printf '%s\n' "$path"
  done < <(find "$home" -path "$home/build" -prune -o -type l -print | sort)
}

echo "== removes every installer symlink and names each =="

home=$(sandbox uninstall-links)
install "$home" --target all
before=$(our_links "$home")
before_count=$(wc -l <<<"$before")
assert 'the install made links to remove (setup)' test "$before_count" -gt 10
install "$home" --uninstall --target all
assert 'uninstall exits 0' same "$LAST_EXIT" 0
assert 'no installer symlink remains' same "$(our_links "$home")" ""
named=0
while IFS= read -r path; do
  rg -qxF "removed: $path" <<<"$LAST_OUTPUT" && named=$((named + 1))
done <<<"$before"
assert 'output names each removed link' same "$named" "$before_count"

echo "== disables the installer's timers =="

home=$(sandbox uninstall-timers)
install "$home" --target claude
: >"$home/state/systemctl"
install "$home" --uninstall --target claude
for timer in upstream-watch.timer engram-backup.timer engram-backup-verify.timer; do
  assert "systemctl disables $timer" rg -qxF -- "--user disable --now $timer" "$home/state/systemctl"
  assert "output names $timer" rg -qxF "disabled: $timer" <<<"$LAST_OUTPUT"
done
assert 'systemctl reloads the user units last' same "$(tail -n1 "$home/state/systemctl")" "--user daemon-reload"

echo "== unsets our core.hooksPath, keeps a foreign one =="

# hooks_path HOME: the sandbox's global core.hooksPath, empty when unset.
hooks_path() { GIT_CONFIG_GLOBAL="$1/.gitconfig" GIT_CONFIG_NOSYSTEM=1 git config --global --get core.hooksPath || true; }

home=$(sandbox uninstall-hookspath)
install "$home" --target claude
assert 'the install set core.hooksPath (setup)' same "$(hooks_path "$home")" "$ROOT/git-hooks"
install "$home" --uninstall --target claude
assert 'our core.hooksPath is unset' same "$(hooks_path "$home")" ""
assert 'output names the unset hooksPath' rg -qxF "unset: core.hooksPath $ROOT/git-hooks" <<<"$LAST_OUTPUT"

home=$(sandbox uninstall-foreign-hookspath)
mkdir -p "$home/my-hooks"
GIT_CONFIG_GLOBAL="$home/.gitconfig" git config --global core.hooksPath "$home/my-hooks"
install "$home" --uninstall --target claude
assert 'a foreign core.hooksPath is kept' same "$(hooks_path "$home")" "$home/my-hooks"
assert 'output names no unset hooksPath' test -z "$(rg -F 'unset: core.hooksPath' <<<"$LAST_OUTPUT")"

echo "== removes our plugins and the marketplace =="

home=$(sandbox uninstall-plugins)
printf 'other@elsewhere\n' >"$home/state/plugins"
install "$home" --target claude
assert 'the install added our plugins (setup)' same "$(rg -c '@ai-dotfiles$' "$home/state/plugins")" 3
install "$home" --uninstall --target claude
assert 'no ai-dotfiles plugin remains' same "$(cat "$home/state/plugins")" "other@elsewhere"
assert 'the ai-dotfiles marketplace is removed' test ! -e "$home/state/marketplace"
for plugin in flow toolkit look; do
  assert "output names $plugin" rg -qxF "uninstalled plugin: $plugin@ai-dotfiles" <<<"$LAST_OUTPUT"
done
assert 'output names the marketplace' rg -qxF "removed marketplace: ai-dotfiles" <<<"$LAST_OUTPUT"

echo "== drops the toolkit key from agy's hooks.json, keeps the others =="

home=$(sandbox uninstall-agy-hooks)
mkdir -p "$home/.gemini/config"
hooks="$home/.gemini/config/hooks.json"
jq -n '{herdr: {Stop: [{type: "command", command: "herdr stop"}]}}' >"$hooks"
install "$home" --target antigravity
assert 'the install set the toolkit key (setup)' json_true "$hooks" '.toolkit != null'
install "$home" --uninstall --target antigravity
assert 'hooks.json keeps only the herdr key' same "$(jq -c . "$hooks")" '{"herdr":{"Stop":[{"type":"command","command":"herdr stop"}]}}'
assert 'output names the dropped key' rg -qxF "removed toolkit hooks: $hooks" <<<"$LAST_OUTPUT"

echo "== leaves what the installer did not put there, points at settings.json =="

# state_of PATH...: type, link target or content hash of each PATH, one per line.
state_of() {
  local path
  for path in "$@"; do
    if [[ -L $path ]]; then
      printf 'link %s -> %s\n' "$path" "$(readlink "$path")"
    elif [[ -f $path ]]; then
      printf 'file %s %s\n' "$path" "$(sha256sum <"$path" | cut -d' ' -f1)"
    elif [[ -d $path ]]; then
      printf 'dir %s %s\n' "$path" "$(find "$path" -type f | sort | wc -l)"
    else
      printf 'missing %s\n' "$path"
    fi
  done
}

home=$(sandbox uninstall-leave-alone)
install "$home" --target all
ln -s /usr/bin/true "$home/.local/bin/my-tool"
printf '# mine\n' >"$home/.claude/output-styles/mine.md"
printf 'old copy\n' >"$home/.claude/CLAUDE.md.bak-20200101-000001"
mkdir -p "$home/.config/opencode/skills/my-skill" "$home/.gemini/antigravity-cli/skills-backup/old-skill"
printf 'x\n' >"$home/.config/opencode/skills/my-skill/SKILL.md"
printf 'x\n' >"$home/.gemini/antigravity-cli/skills-backup/old-skill/SKILL.md"
kept=("$home/.local/bin/my-tool" "$home/.claude/output-styles/mine.md"
  "$home/.claude/CLAUDE.md.bak-20200101-000001" "$home/.config/opencode/skills/my-skill"
  "$home/.gemini/antigravity-cli/skills-backup/old-skill" "$home/.claude/settings.json")
before=$(state_of "${kept[@]}")
assert 'every kept path exists (setup)' test -z "$(rg '^missing' <<<"$before")"
install "$home" --uninstall --target all
assert 'what the installer did not put there is untouched' same "$(state_of "${kept[@]}")" "$before"
assert 'output says settings.json keeps the merged entries' \
  rg -qF "$home/.claude/settings.json keeps the merged entries; clean it by hand" <<<"$LAST_OUTPUT"

echo "== --dry-run names each removal and changes nothing =="

# everything HOME: type, link target or content hash of every path under HOME
# but the stubs' state and the build dir.
everything() {
  local home=$1 paths
  mapfile -t paths < <(find "$home" \( -path "$home/state" -o -path "$home/build" \) -prune -o -print | sort)
  state_of "${paths[@]}"
}

home=$(sandbox uninstall-dry-run)
mkdir -p "$home/.gemini/config"
jq -n '{herdr: {}}' >"$home/.gemini/config/hooks.json"
install "$home" --target all
links=$(our_links "$home")
before=$(everything "$home")
install "$home" --uninstall --dry-run --target all
assert 'dry-run exits 0' same "$LAST_EXIT" 0
assert 'dry-run changes nothing' same "$(everything "$home")" "$before"
named=0
while IFS= read -r path; do
  rg -qxF "[dry-run] rm $path" <<<"$LAST_OUTPUT" && named=$((named + 1))
done <<<"$links"
assert 'dry-run names each link it would remove' same "$named" "$(wc -l <<<"$links")"
assert 'dry-run names the timer it would disable' \
  rg -qxF "[dry-run] systemctl --user disable --now upstream-watch.timer" <<<"$LAST_OUTPUT"
assert 'dry-run names the hooksPath it would unset' \
  rg -qxF "[dry-run] git config --global --unset core.hooksPath" <<<"$LAST_OUTPUT"
assert 'dry-run names the plugin it would uninstall' \
  rg -qxF "[dry-run] claude plugin uninstall flow@ai-dotfiles" <<<"$LAST_OUTPUT"
assert 'dry-run names the marketplace it would remove' \
  rg -qxF "[dry-run] claude plugin marketplace remove ai-dotfiles" <<<"$LAST_OUTPUT"
assert 'dry-run names the hooks key it would remove' \
  rg -qxF "[dry-run] would remove the toolkit key from $home/.gemini/config/hooks.json" <<<"$LAST_OUTPUT"
assert 'dry-run claims no change it did not make' \
  test -z "$(rg '^(removed|disabled|unset|uninstalled plugin|removed marketplace|removed toolkit hooks): ' <<<"$LAST_OUTPUT")"

finish_cases
