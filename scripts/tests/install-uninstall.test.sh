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

finish_cases
