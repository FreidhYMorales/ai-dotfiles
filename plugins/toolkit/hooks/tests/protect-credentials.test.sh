#!/usr/bin/env bash
# Tests for protect-credentials.sh. Run: bash plugins/toolkit/hooks/tests/protect-credentials.test.sh
set -u

HOOK="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/protect-credentials.sh"
failures=0

# run_raw EXPECTED_EXIT LABEL STDIN: sets ERR to the hook's stderr.
run_raw() {
  local expected=$1 label=$2 input=$3 actual
  ERR=$(printf '%s' "$input" | bash "$HOOK" 2>&1 >/dev/null)
  actual=$?
  if [[ $actual -eq $expected ]]; then
    printf 'PASS  [exit %d] %s\n' "$actual" "$label"
  else
    printf 'FAIL  [want %d, got %d] %s\n' "$expected" "$actual" "$label"
    failures=$((failures + 1))
  fi
}

# check EXPECTED_EXIT COMMAND: wraps COMMAND in a Bash tool payload.
check() {
  local payload
  payload=$(jq -n --arg cmd "$2" '{tool_name: "Bash", tool_input: {command: $cmd}}')
  run_raw "$1" "$2" "$payload"
}

block() { check 2 "$1"; }

# err_has LABEL TEXT: the last stderr contains TEXT.
err_has() {
  if [[ $ERR == *"$2"* ]]; then
    printf 'PASS  %s\n' "$1"
  else
    printf 'FAIL  %s (stderr: %s)\n' "$1" "$ERR"
    failures=$((failures + 1))
  fi
}

echo "== must block =="
block 'bat ~/.config/gh/hosts.yml'
err_has 'the reason names the protected path' '.config/gh'

echo "== every spelling and program is blocked =="
# shellcheck disable=SC2016 # $HOME is command text, not expanded here
block 'bat $HOME/.config/gh/hosts.yml'
# shellcheck disable=SC2016
block 'jq . "${HOME}/.config/restic/engram.env"'
err_has 'restic: the reason names .config/restic' '.config/restic'
block 'bat /home/u/.git-credentials'
err_has 'git credentials: the reason names .git-credentials' '.git-credentials'
block 'cp ~/.git-credentials /tmp/x'
block 'rg token .env.production'
err_has '.env.*: the reason names the file' '.env.production'
block 'cd app && bat ./config/.env.local'
err_has '.env.* in a subdirectory: the reason names the file' '.env.local'

echo "== the block never shows the secret =="
FAKE_HOME=$(mktemp -d)
trap 'rm -rf "$FAKE_HOME"' EXIT
printf 'https://user:SECRET123@github.com\n' >"$FAKE_HOME/.git-credentials"
payload=$(jq -n '{tool_name: "Bash", tool_input: {command: "bat ~/.git-credentials"}}')
out=$(printf '%s' "$payload" | HOME=$FAKE_HOME bash "$HOOK" 2>&1)
code=$?
if [[ $code -eq 2 && $out != *SECRET123* ]]; then
  printf 'PASS  blocked without echoing the file content\n'
else
  printf 'FAIL  blocked without echoing the file content (exit %d, output: %s)\n' "$code" "$out"
  failures=$((failures + 1))
fi

if [[ $failures -gt 0 ]]; then
  printf '%d case(s) failed\n' "$failures"
  exit 1
fi
echo "All cases passed"
