#!/usr/bin/env bash
# Tests for host-info.sh. Run: bash plugins/toolkit/hooks/tests/host-info.test.sh
set -u

HOOK="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/host-info.sh"
BASH_BIN=$(command -v bash)
JQ_BIN=$(command -v jq)
failures=0
TMP_ROOT=$(mktemp -d)
trap 'rm -rf "$TMP_ROOT"' EXIT

# host NAME KERNEL [TOOL...]: a fake machine whose PATH holds only a `uname`
# stub printing KERNEL, jq, and empty stubs for each TOOL. Prints its dir.
host() {
  local dir="$TMP_ROOT/$1" kernel=$2 tool
  shift 2
  mkdir -p "$dir/bin"
  printf '#!%s\necho %s\n' "$BASH_BIN" "$kernel" >"$dir/bin/uname"
  for tool in "$@"; do printf '#!%s\n' "$BASH_BIN" >"$dir/bin/$tool"; done
  chmod +x "$dir/bin"/*
  ln -s "$JQ_BIN" "$dir/bin/jq"
  printf '%s\n' "$dir"
}

# run DIR [SOURCE] [ENV...]: run the hook on fake host DIR; context in $LAST_CONTEXT.
LAST_CONTEXT=""
run() {
  local dir=$1 source=${2:-startup}
  shift 2 2>/dev/null || shift
  LAST_CONTEXT=$(jq -n --arg s "$source" '{hook_event_name: "SessionStart", source: $s}' |
    env -i PATH="$dir/bin" SHELL=/usr/bin/zsh OS_RELEASE_FILE="$dir/os-release" \
      PROC_VERSION_FILE="$dir/proc-version" "$@" "$BASH_BIN" "$HOOK" 2>/dev/null |
    "$JQ_BIN" -r '.hookSpecificOutput.additionalContext // empty' 2>/dev/null)
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

has() { [[ $LAST_CONTEXT == *"$1"* ]]; }
lacks() { [[ $LAST_CONTEXT != *"$1"* ]]; }

echo "== linux distributions =="

dir=$(host arch Linux pacman yay)
printf 'NAME="Arch Linux"\nPRETTY_NAME="Arch Linux"\nID=arch\n' >"$dir/os-release"
run "$dir"
assert 'arch: names the distro' has 'Host (dev machine): Arch Linux'
assert 'arch: names pacman' has 'packages: pacman'
assert 'arch: names the AUR helper' has 'AUR: yay'
assert 'arch: names the shell' has 'shell: zsh'
assert 'arch: warns host is not the target' has 'not the project target platform'

dir=$(host ubuntu Linux apt)
printf 'PRETTY_NAME="Ubuntu 24.04.1 LTS"\nID=ubuntu\n' >"$dir/os-release"
run "$dir"
assert 'ubuntu: names the distro' has 'Ubuntu 24.04.1 LTS'
assert 'ubuntu: names apt' has 'packages: apt'
assert 'ubuntu: no AUR helper' lacks 'AUR'

dir=$(host wsl Linux apt)
printf 'PRETTY_NAME="Ubuntu 22.04 LTS"\n' >"$dir/os-release"
printf 'Linux version 5.15.0-microsoft-standard-WSL2\n' >"$dir/proc-version"
run "$dir"
assert 'wsl: flags WSL' has 'Ubuntu 22.04 LTS (WSL)'

dir=$(host norelease Linux)
run "$dir"
assert 'missing os-release falls back to Linux' has 'Host (dev machine): Linux'
assert 'no package manager says unknown' has 'packages: unknown'

echo "== other systems =="

dir=$(host mac Darwin brew)
printf '#!%s\necho 15.1\n' "$BASH_BIN" >"$dir/bin/sw_vers"
chmod +x "$dir/bin/sw_vers"
run "$dir"
assert 'macos: names version' has 'macOS 15.1'
assert 'macos: names brew' has 'packages: brew'

dir=$(host windows MINGW64_NT-10.0-26100 winget scoop)
run "$dir"
assert 'windows: flags Git Bash' has 'Windows (Git Bash/MSYS)'
assert 'windows: lists every manager found' has 'packages: winget, scoop'

echo "== installed tools =="

dir=$(host tools Linux pacman docker gh ffmpeg yt-dlp)
printf 'PRETTY_NAME="Arch Linux"\n' >"$dir/os-release"
run "$dir"
assert 'lists installed tools' has 'tools: '
assert 'lists docker' has 'docker'
assert 'lists gh' has 'gh'
assert 'lists media tools' has 'ffmpeg, yt-dlp'
assert 'omits tools that are not installed' lacks 'kubectl'
assert 'package managers are not repeated as tools' lacks 'tools: pacman'

echo "== when it runs =="

dir=$(host sources Linux pacman)
printf 'PRETTY_NAME="Arch Linux"\n' >"$dir/os-release"
for source in startup clear compact; do
  run "$dir" "$source"
  assert "$source injects context" has 'Arch Linux'
done
run "$dir" resume
assert 'resume stays silent (context already in transcript)' test -z "$LAST_CONTEXT"
run "$dir" startup SKIP_HOST_INFO=1
assert 'SKIP_HOST_INFO=1 stays silent' test -z "$LAST_CONTEXT"

echo
if [[ $failures -gt 0 ]]; then
  echo "$failures case(s) failed"
  exit 1
fi
echo "All cases passed"
