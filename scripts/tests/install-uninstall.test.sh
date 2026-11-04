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

finish_cases
