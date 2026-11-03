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

if [[ $failures -gt 0 ]]; then
  printf '%d case(s) failed\n' "$failures"
  exit 1
fi
echo "All cases passed"
