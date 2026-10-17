#!/usr/bin/env bash
# Tests for claude/statusline.sh. Run: bash scripts/tests/statusline.test.sh
set -u

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SCRIPT="$ROOT/claude/statusline.sh"
failures=0
TMP_ROOT=$(mktemp -d)
trap 'rm -rf "$TMP_ROOT"' EXIT
export GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1

repo="$TMP_ROOT/my-repo"
mkdir -p "$repo"
git -C "$repo" init -q -b feature/x
git -C "$repo" -c user.name=t -c user.email=t@t -c core.hooksPath=/dev/null commit -q --allow-empty -m init

# payload DIR CTX [FIVE_HOUR] [RESETS_EPOCH]: a statusline JSON input.
payload() {
  jq -n --arg d "$1" --argjson ctx "$2" --arg five "${3:-}" --arg resets "${4:-}" '{
    model: {display_name: "Opus"},
    workspace: {current_dir: $d, project_dir: $d},
    context_window: {used_percentage: $ctx},
    rate_limits: (if $five == "" then null else
      {five_hour: {used_percentage: ($five | tonumber), resets_at: ($resets | tonumber)}} end)
  }'
}

# render JSON [ENV...]: run the statusline; plain text (no ANSI) in $LINE, raw in $RAW.
LINE=""
RAW=""
render() {
  local json=$1
  shift
  RAW=$(printf '%s' "$json" | env -u ZELLIJ_SESSION_NAME "$@" bash "$SCRIPT" 2>/dev/null)
  # Strip ANSI colors in pure bash (no extra tools in CI).
  LINE=$RAW
  local ansi=$'\e\[[0-9;]*m'
  while [[ $LINE =~ $ansi ]]; do LINE=${LINE/"${BASH_REMATCH[0]}"/}; done
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

has() { [[ $LINE == *"$1"* ]]; }
lacks() { [[ $LINE != *"$1"* ]]; }
raw_has() { [[ $RAW == *"$1"* ]]; }

echo "== content =="

render "$(payload "$repo" 34 62 "$(date -d 'today 14:20' +%s)")"
assert 'shows the model' has 'Opus'
assert 'shows the project folder' has 'my-repo'
assert 'shows the git branch' has 'feature/x'
assert 'shows context usage' has 'ctx 34%'
assert 'shows a context bar' has '▓'
assert 'shows the 5-hour quota' has '5h 62%'
assert 'shows when the quota resets' has 'resets 14:20'
assert 'prints a single line' test "$(printf '%s\n' "$RAW" | wc -l)" -eq 1

printf 'x\n' >"$repo/dirty.txt"
render "$(payload "$repo" 10)"
assert 'marks a dirty tree' has 'feature/x*'
rm "$repo/dirty.txt"
render "$(payload "$repo" 10)"
assert 'a clean tree has no dirty mark' lacks 'feature/x*'

echo "== colors =="

render "$(payload "$repo" 20)"
assert 'low context is green' raw_has $'\e[32mctx 20%'
render "$(payload "$repo" 65)"
assert 'mid context is yellow' raw_has $'\e[33mctx 65%'
render "$(payload "$repo" 90)"
assert 'high context is red' raw_has $'\e[31mctx 90%'

echo "== optional parts =="

render "$(payload "$repo" 10)"
assert 'no rate-limit data hides the quota' lacks '5h'

render "$(payload "$repo" 10)" ZELLIJ_SESSION_NAME=claude-my-repo
assert 'shows the zellij session' has 'zj claude-my-repo'
render "$(payload "$repo" 10)"
assert 'outside zellij shows no session' lacks 'zj'

plain="$TMP_ROOT/plain"
mkdir -p "$plain"
render "$(payload "$plain" 10)"
assert 'outside git shows no branch' lacks '⎇'

render '{}'
assert 'empty input still renders' has 'ctx 0%'

echo
if [[ $failures -gt 0 ]]; then
  echo "$failures case(s) failed"
  exit 1
fi
echo "All cases passed"
