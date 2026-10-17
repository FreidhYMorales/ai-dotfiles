#!/usr/bin/env bash
# Tests for bin/claude-perms-audit. Run: bash scripts/tests/claude-perms-audit.test.sh
set -u

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SCRIPT="$ROOT/bin/claude-perms-audit"
failures=0
TMP_ROOT=$(mktemp -d)
trap 'rm -rf "$TMP_ROOT"' EXIT

# settings DIR FILE RULE...: write DIR/.claude/FILE with the given allow rules.
settings() {
  local dir=$1 file=$2
  shift 2
  mkdir -p "$dir/.claude"
  printf '%s\n' "$@" | jq -R . | jq -s '{permissions: {allow: .}, model: "keep-me"}' >"$dir/.claude/$file"
}

home="$TMP_ROOT/home"
live_session="$TMP_ROOT/tmp/claude-1000/-proj/live-session"
mkdir -p "$live_session/scratchpad"
settings "$home/risky" settings.local.json \
  'Bash(python3 *)' 'Bash(node:*)' 'Bash(*)' 'Write' 'Edit(**)' \
  'Bash(pdfinfo __TRACKED_VAR__/x.pdf)' \
  "Bash(rm -rf $TMP_ROOT/tmp/claude-1000/-proj/dead-session/scratchpad/x)" \
  "Bash(mkdir -p $live_session/scratchpad/y)" \
  'Bash(eza *)' 'Bash(npm run test)' 'Read(//mnt/backup/**)'
settings "$home/clean" settings.json 'Bash(npm run lint)' 'Bash(git status)'

# audit [ARGS...]: run the audit; output in $LAST_OUTPUT.
LAST_OUTPUT=""
LAST_EXIT=0
audit() {
  LAST_OUTPUT=$(env HOME="$home" bash "$SCRIPT" "$@" 2>&1)
  LAST_EXIT=$?
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

flags() { [[ $LAST_OUTPUT == *"$1"*"$2"* ]]; }
lacks() { [[ $LAST_OUTPUT != *"$1"* ]]; }

echo "== risky rules are flagged =="

audit "$home"
assert 'findings exit 1' test "$LAST_EXIT" -eq 1
assert 'interpreter wildcard (space form)' flags 'interpreter wildcard' 'Bash(python3 *)'
assert 'interpreter wildcard (colon form)' flags 'interpreter wildcard' 'Bash(node:*)'
assert 'any command' flags 'any command' 'Bash(*)'
assert 'unrestricted write' flags 'any file' 'Write'
assert 'unrestricted edit' flags 'any file' 'Edit(**)'
assert 'placeholder rule' flags 'never matches' '__TRACKED_VAR__'
assert 'dead session path' flags 'dead path' 'dead-session'
assert 'findings name the file' flags 'risky/.claude/settings.local.json' ''

echo "== safe rules are left alone =="

assert 'a live session path is not flagged' lacks 'live-session'
assert 'eza wildcard is fine' lacks 'Bash(eza *)'
assert 'specific commands are fine' lacks 'npm run test'
assert 'reads of a specific tree are fine' lacks '/mnt/backup'
assert 'a clean file is not reported' lacks 'clean/.claude'

audit "$home/clean"
assert 'a clean tree exits 0' test "$LAST_EXIT" -eq 0
assert 'a clean tree says so' flags 'no risky' ''

echo "== --fix =="

audit --fix "$home/risky"
risky="$home/risky/.claude/settings.local.json"
assert 'fix keeps safe rules' test "$(jq -c '.permissions.allow' "$risky")" == \
  "$(jq -nc --arg live "Bash(mkdir -p $live_session/scratchpad/y)" '[$live, "Bash(eza *)", "Bash(npm run test)", "Read(//mnt/backup/**)"]')"
assert 'fix keeps every other setting' test "$(jq -r '.model' "$risky")" == keep-me
assert 'fix leaves a backup' test -n "$(compgen -G "$risky.bak-*")"
audit "$home/risky"
assert 'after fix the tree is clean' test "$LAST_EXIT" -eq 0

echo
if [[ $failures -gt 0 ]]; then
  echo "$failures case(s) failed"
  exit 1
fi
echo "All cases passed"
