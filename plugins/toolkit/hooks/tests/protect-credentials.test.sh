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
allow() { check 0 "$1"; }

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

echo "== globs that expand to a .env.* file are blocked =="
block 'cat .env.*'
err_has 'a .env.* glob: the reason names it' '.env.*'
block 'rg TOKEN .env*'
block 'bat config/.env.[lp]*'

echo "== tools that do not name the files run =="
allow 'gh pr checks 31'
allow 'engram-backup --verify'
allow 'rg foo .'
allow 'bat ~/.config/ghostty/config'
allow "node -e 'console.log(process.env.HOME)'"
allow 'bat .envrc'

echo "== registered for every Bash call =="
hooks_json="$(dirname "$HOOK")/hooks.json"
if jq -e '[.hooks.PreToolUse[] | select(.matcher == "Bash") | .hooks[].command
    | select(endswith("/hooks/protect-credentials.sh"))] | length == 1' "$hooks_json" >/dev/null 2>&1; then
  printf 'PASS  hooks.json runs protect-credentials on PreToolUse Bash\n'
else
  printf 'FAIL  hooks.json runs protect-credentials on PreToolUse Bash\n'
  failures=$((failures + 1))
fi

echo "== fails open =="
run_raw 0 'a non-Bash tool is not checked' \
  '{"tool_name":"Write","tool_input":{"file_path":"notes.md","content":"see ~/.git-credentials"}}'
run_raw 0 'invalid JSON is let through' 'not json ~/.git-credentials'
nojq=$(mktemp -d)
ln -s "$(command -v bash)" "$nojq/bash"
out=$(printf '%s' '{"tool_name":"Bash","tool_input":{"command":"bat ~/.git-credentials"}}' | PATH=$nojq bash "$HOOK" 2>&1)
code=$?
rm -rf "$nojq"
if [[ $code -eq 0 ]]; then
  printf 'PASS  [exit 0] without jq the command is let through\n'
else
  printf 'FAIL  [want 0, got %d] without jq the command is let through (%s)\n' "$code" "$out"
  failures=$((failures + 1))
fi

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
