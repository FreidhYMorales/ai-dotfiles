#!/usr/bin/env bash
# Tests for hooks-path.sh. Run: bash plugins/toolkit/hooks/tests/hooks-path.test.sh
# Each case runs the hook with a throwaway global git config.
set -u

HOOK="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/hooks-path.sh"
failures=0
TMP_ROOT=$(mktemp -d)
trap 'rm -rf "$TMP_ROOT"' EXIT

# machine NAME: a HOME with an empty global git config. Prints it.
machine() {
  local home="$TMP_ROOT/$1"
  mkdir -p "$home"
  : >"$home/.gitconfig"
  printf '%s\n' "$home"
}

# hooks_path HOME VALUE: set the global core.hooksPath of HOME.
hooks_path() { git config --file "$1/.gitconfig" core.hooksPath "$2"; }

# run HOME [SOURCE]: run the hook; message in $LAST_MESSAGE.
LAST_MESSAGE=""
LAST_EXIT=0
run() {
  local home=$1 source=${2:-startup} out="$TMP_ROOT/hook.out"
  jq -n --arg s "$source" '{hook_event_name: "SessionStart", source: $s}' |
    (cd "$home" && HOME="$home" GIT_CONFIG_GLOBAL="$home/.gitconfig" GIT_CONFIG_NOSYSTEM=1 \
      bash "$HOOK") >"$out" 2>/dev/null
  LAST_EXIT=$?
  LAST_MESSAGE=$(jq -r '.systemMessage // empty' <"$out" 2>/dev/null)
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

says() { [[ $LAST_MESSAGE == *"$1"* ]]; }
silent() { [[ -z $LAST_MESSAGE && $LAST_EXIT -eq 0 ]]; }

echo "== dangling hooksPath =="

home=$(machine dangling)
hooks_path "$home" "$TMP_ROOT/moved-repo/git-hooks"
run "$home"
assert 'a dangling hooksPath names the path' says "$TMP_ROOT/moved-repo/git-hooks"
assert 'it says gitleaks is not running' says 'gitleaks'
assert 'it points to the fix' says './install.sh'
assert 'warning exits 0' test "$LAST_EXIT" -eq 0

echo "== healthy or unset hooksPath =="

home=$(machine unset)
run "$home"
assert 'an unset hooksPath stays silent' silent

home=$(machine healthy)
mkdir -p "$home/dotfiles/git-hooks"
hooks_path "$home" "$home/dotfiles/git-hooks"
run "$home"
assert 'a hooksPath to an existing directory stays silent' silent

# A relative hooksPath is resolved inside each repo, so it cannot dangle globally.
home=$(machine relative)
hooks_path "$home" .githooks
run "$home"
assert 'a relative hooksPath stays silent' silent

echo
if [[ $failures -gt 0 ]]; then
  echo "$failures case(s) failed"
  exit 1
fi
echo "All cases passed"
