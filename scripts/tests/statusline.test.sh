#!/usr/bin/env bash
# Tests for claude/statusline.sh. Run: bash scripts/tests/statusline.test.sh
set -u

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SCRIPT="$ROOT/claude/statusline.sh"
failures=0
TMP_ROOT=$(mktemp -d)
trap 'rm -rf "$TMP_ROOT"' EXIT
export GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1
# Deterministic reset times and character-based string slicing.
export TZ=UTC LC_ALL=C.UTF-8
RESETS=1700000000 # 22:13 UTC

repo="$TMP_ROOT/my-repo"
mkdir -p "$repo"
git -C "$repo" init -q -b feature/x
git -C "$repo" -c user.name=t -c user.email=t@t -c core.hooksPath=/dev/null commit -q --allow-empty -m init

# payload DIR CTX [FIVE] [SEVEN] [MODEL]: a statusline JSON input.
# Empty FIVE or SEVEN leaves that quota out; both empty drops rate_limits.
payload() {
  jq -n --arg d "$1" --argjson ctx "$2" --arg five "${3:-}" --arg seven "${4:-}" \
    --arg model "${5:-Opus}" --argjson resets "$RESETS" '{
    model: {display_name: $model},
    workspace: {current_dir: $d, project_dir: $d},
    context_window: {used_percentage: $ctx},
    rate_limits: ((if $five == "" then {} else
        {five_hour: {used_percentage: ($five | tonumber), resets_at: $resets}} end)
      + (if $seven == "" then {} else
        {seven_day: {used_percentage: ($seven | tonumber)}} end)
      | if . == {} then null else . end)
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
matches() { [[ $LINE =~ $1 ]]; }

echo "== order and content =="

render "$(payload "$repo" 42 84 61)"
assert 'meters come before the place' matches '^ctx .* 42% · 5h .* 84% ↻22:13 · 7d .* 61% · Opus · my-repo ⎇ feature/x$'
assert 'prints a single line' test "$(printf '%s\n' "$RAW" | wc -l)" -eq 1

printf 'x\n' >"$repo/dirty.txt"
render "$(payload "$repo" 10)"
assert 'marks a dirty tree' has 'feature/x*'
rm "$repo/dirty.txt"
render "$(payload "$repo" 10)"
assert 'a clean tree has no dirty mark' lacks 'feature/x*'

echo "== bars =="

# 48 steps: round(pct * 48 / 100) eighth-cells; 6 cells; the rest is a dim track.
render "$(payload "$repo" 0)"
assert '0% is an all-track bar' has 'ctx ░░░░░░ 0%'
assert '0% track is dim' raw_has $'\e[2m░░░░░░'
render "$(payload "$repo" 2)"
assert '1 step is the thinnest glyph' has 'ctx ▏░░░░░ 2%'
render "$(payload "$repo" 42)"
assert '42% is 2 full cells, a partial and a track' has 'ctx ██▌░░░ 42%'
render "$(payload "$repo" 98)"
assert '47 steps leave the last cell almost full' has 'ctx █████▉ 98%'
render "$(payload "$repo" 100)"
assert '48 steps fill the bar with no track' has 'ctx ██████ 100%'

echo "== colors =="

for pct in 49 50 79 80; do
  render "$(payload "$repo" "$pct")"
  case $pct in
    49) want=$'\e[32m' ;;
    50 | 79) want=$'\e[33m' ;;
    *) want=$'\e[31m' ;;
  esac
  assert "$pct% uses the right color" raw_has "${want}ctx "
done

echo "== 5h reset =="

render "$(payload "$repo" 10 80 20)"
assert 'reset shows at 80%' has '↻22:13'
render "$(payload "$repo" 10 79 20)"
assert 'reset hides at 79%' lacks '↻'

echo "== 7d meter =="

render "$(payload "$repo" 10 20 61)"
assert '7d meter follows 5h' matches '5h .* 20% · 7d .* 61%'

echo "== place =="

render "$(payload "$repo" 10 "" "" "Claude Opus")"
assert 'strips a leading "Claude "' has ' Opus · '
assert 'no "Claude" remains' lacks 'Claude'

long="$TMP_ROOT/abcdefghijklmnopqrstuvwxyz1234"
mkdir -p "$long"
git -C "$long" init -q -b feature/abcdefghijklmnopqrstuvwxyz0123456789
git -C "$long" -c user.name=t -c user.email=t@t -c core.hooksPath=/dev/null commit -q --allow-empty -m init
render "$(payload "$long" 10)"
assert 'repo is cut to 15 chars plus an ellipsis' has ' abcdefghijklmno… ⎇ '
assert 'branch is cut to 19 chars plus an ellipsis' has ' feature/abcdefghijk…'
assert 'no text past the cuts' lacks 'abcdefghijklmnop'

echo "== length budget =="

printf 'x\n' >"$long/dirty.txt"
render "$(payload "$long" 100 100 100 "Sonnet")"
assert "worst case stays within 110 columns (got ${#LINE})" test "${#LINE}" -le 110
assert 'worst case keeps every meter' matches '^ctx .* 100% · 5h .* 100% ↻22:13 · 7d .* 100% · '
rm "$long/dirty.txt"

echo "== degraded states =="

plain="$TMP_ROOT/plain"
mkdir -p "$plain"
render "$(payload "$plain" 10 20 30)"
assert 'outside git shows no branch' lacks '⎇'
assert 'outside git keeps the meters' matches '^ctx .* 10% · 5h .* 20% · 7d .* 30% · Opus · plain$'

render "$(payload "$repo" 10)"
assert 'no rate_limits shows only ctx' lacks '5h'
assert 'no rate_limits hides 7d' lacks '7d'
assert 'no rate_limits keeps ctx and place' matches '^ctx .* 10% · Opus · my-repo ⎇ feature/x$'

render "$(payload "$repo" 10 20)"
assert 'missing 7d omits only 7d' matches '^ctx .* 10% · 5h .* 20% · Opus'
assert 'missing 7d drops the 7d label' lacks '7d'
render "$(payload "$repo" 10 "" 30)"
assert 'missing 5h omits only 5h' matches '^ctx .* 10% · 7d .* 30% · Opus'

render "$(payload "$repo" 10)" ZELLIJ_SESSION_NAME=claude-my-repo
assert 'never shows the zellij session' lacks 'zj'

render '{}'
assert 'empty input still renders' has 'ctx ░░░░░░ 0%'

echo
if [[ $failures -gt 0 ]]; then
  echo "$failures case(s) failed"
  exit 1
fi
echo "All cases passed"
