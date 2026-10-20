#!/usr/bin/env bash
# Tests for pack-hint.sh and `ai-pack hint`. Run: bash plugins/toolkit/hooks/tests/pack-hint.test.sh
# The hook runs the real bin/ai-pack against fixture projects; state, data and
# HOME live in a temp dir, so the user's real state is never read or written.
set -u

HOOK="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/pack-hint.sh"
ROOT="$(cd "$(dirname "$HOOK")/../../.." && pwd)"
failures=0
TMP_ROOT=$(realpath "$(mktemp -d)")
trap 'rm -rf "$TMP_ROOT"' EXIT
export GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1
unset AI_HOOKS_OFF AI_PACK_STATE AI_PACK_MANIFEST AI_PACK_NOW

HOME_DIR="$TMP_ROOT/home"
mkdir -p "$HOME_DIR"
NOW=1800000000
DAY=86400

# A PATH without any dir that holds a real ai-pack, so the PATH lookup is under test control.
CLEAN_PATH=""
IFS=: read -ra _dirs <<<"$PATH"
for _d in "${_dirs[@]}"; do [[ -x $_d/ai-pack ]] || CLEAN_PATH+="${CLEAN_PATH:+:}$_d"; done

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

# fresh NAME: new state dir ($STATE_HOME/ai-pack), bin dir ($BINDIR) and project ($PROJ, vite).
fresh() {
  STATE_HOME="$TMP_ROOT/$1/state"
  STATE="$STATE_HOME/ai-pack"
  BINDIR="$TMP_ROOT/$1/bin"
  PROJ="$TMP_ROOT/$1/proj"
  mkdir -p "$BINDIR" "$PROJ"
  git -C "$PROJ" init -q
  printf '{"devDependencies":{"vite":"^5"}}\n' >"$PROJ/package.json"
}

use_real() { ln -sf "$ROOT/bin/ai-pack" "$BINDIR/ai-pack"; }
stub() { printf '#!/usr/bin/env bash\n%s\n' "$1" >"$BINDIR/ai-pack" && chmod +x "$BINDIR/ai-pack"; }

# snapshot DIR: names, mtimes and sizes of everything under DIR except .git.
snapshot() {
  (
    cd "$1" || exit 1
    shopt -s globstar dotglob
    for f in **; do
      [[ $f == .git || $f == .git/* ]] || stat -c '%n %Y %s' "$f"
    done
  )
}

# run_hook SOURCE CWD [ENV...]: output in $OUT, exit code in $CODE.
OUT=""
CODE=0
run_hook() {
  local source=$1 cwd=$2
  shift 2
  OUT=$(jq -nc --arg s "$source" --arg c "$cwd" '{hook_event_name: "SessionStart", source: $s, cwd: $c}' |
    env HOME="$HOME_DIR" XDG_STATE_HOME="$STATE_HOME" XDG_DATA_HOME="$HOME_DIR/data" XDG_BIN_HOME="$HOME_DIR/nobin" \
      PATH="$BINDIR:$CLEAN_PATH" AI_PACK_NOW="$NOW" PACK_HINT_TIMEOUT=10 "$@" bash "$HOOK" 2>/dev/null)
  CODE=$?
}

silent() { [[ $CODE -eq 0 && -z $OUT ]]; }
msg_has() { jq -e --arg s "$1" '.systemMessage | contains($s)' >/dev/null 2>&1 <<<"$OUT"; }
msg_is() { [[ $(jq -r '.systemMessage' <<<"$OUT" 2>/dev/null) == "$1" ]]; }
only_system_message() { jq -e 'keys == ["systemMessage"]' >/dev/null 2>&1 <<<"$OUT"; }
one_line() { [[ $(jq -r '.systemMessage' <<<"$OUT" | wc -l) -eq 1 ]]; }
short() { [[ $(jq -r '.systemMessage' <<<"$OUT" | awk '{print length}') -le 70 ]]; }
shown_at() { jq -e --arg k "$PROJ" --argjson t "$1" '.projects[$k].web == $t' "$STATE/hints.json" >/dev/null 2>&1; }
no_hints_file() { [[ ! -e $STATE/hints.json ]]; }
seed() { mkdir -p "$STATE" && printf '%s\n' "$2" >"$STATE/$1"; }
state_names() {
  local f
  for f in "$STATE"/* "$STATE"/.[!.]*; do [[ -e $f ]] && printf '%s ' "${f##*/}"; done
}
file_is() { [[ $(<"$1") == "$2" ]]; }

echo "== hint shown"
fresh vite
use_real
run_hook startup "$PROJ"
assert "vite project: exits 0" test "$CODE" -eq 0
assert "vite project: hint suggests add web" msg_has "ai-pack add web"
assert "vite project: hint names the ignore command" msg_has "ai-pack ignore web"
assert "vite project: hint names the signal" msg_has "vite"
assert "vite project: systemMessage only" only_system_message
assert "vite project: one line" one_line
assert "vite project: under 71 characters" short
assert "vite project: hints.json records the epoch" shown_at "$NOW"
assert "vite project: hints.json has schema_version 1" jq -e '.schema_version == 1' "$STATE/hints.json"
run_hook startup "$PROJ"
assert "second run is silent" silent
assert "second run keeps the timestamp" shown_at "$NOW"

echo "== cadence"
fresh cad
use_real
seed hints.json "{\"schema_version\":1,\"projects\":{\"$PROJ\":{\"web\":$((NOW - 31 * DAY))}}}"
run_hook startup "$PROJ"
assert "shown 31 days ago: prints again" msg_has "ai-pack add web"
assert "shown 31 days ago: timestamp refreshed" shown_at "$NOW"
seed hints.json "{\"schema_version\":1,\"projects\":{\"$PROJ\":{\"web\":$((NOW - 5 * DAY))}}}"
run_hook startup "$PROJ"
assert "shown 5 days ago: silent" silent
assert "shown 5 days ago: timestamp untouched" shown_at "$((NOW - 5 * DAY))"
seed hints.json "{\"schema_version\":1,\"projects\":{\"$PROJ\":{\"web\":$((NOW - 30 * DAY))}}}"
run_hook startup "$PROJ"
assert "shown exactly 30 days ago: prints" msg_has "ai-pack add web"
seed hints.json "{\"schema_version\":1,\"projects\":{\"$PROJ\":{\"web\":$((NOW - 30 * DAY + 1))}}}"
run_hook startup "$PROJ"
assert "shown 30 days minus 1 second ago: silent" silent

echo "== detection"
fresh html
use_real
rm "$PROJ/package.json"
printf '<html></html>\n' >"$PROJ/index.html"
run_hook startup "$PROJ"
assert "index.html only: hint" msg_has "ai-pack add web"
fresh nodeps
use_real
printf '{"dependencies":{"left-pad":"1"}}\n' >"$PROJ/package.json"
run_hook startup "$PROJ"
assert "package.json without a web dependency: silent" silent
assert "package.json without a web dependency: no hints.json" no_hints_file
fresh react
use_real
printf '{"dependencies":{"react":"18"}}\n' >"$PROJ/package.json"
run_hook startup "$PROJ"
assert "react in dependencies: hint" msg_has "react"
fresh sub
use_real
mkdir -p "$PROJ/src/app"
run_hook startup "$PROJ/src/app"
assert "subdirectory resolves the project root" msg_has "ai-pack add web"
assert "subdirectory: keyed by the git root" shown_at "$NOW"
fresh bare
use_real
rm "$PROJ/package.json"
run_hook startup "$PROJ"
assert "no package.json and no index.html: silent" silent
fresh repo
use_real
run_hook startup "$ROOT"
assert "this dotfiles repo: silent" silent
assert "this dotfiles repo: no hints.json" no_hints_file
assert "this dotfiles repo: no state dir" test ! -e "$STATE"

echo "== silence rules"
fresh ign
use_real
seed ignored.json "{\"schema_version\":1,\"projects\":{\"$PROJ\":[\"web\"]}}"
run_hook startup "$PROJ"
assert "ignored pack: silent" silent
assert "ignored pack: no hints.json" no_hints_file
fresh act
use_real
seed projects.json "{\"schema_version\":1,\"projects\":{\"$PROJ\":{\"tools\":{\"playwright\":{\"version\":\"0.1.22\"},\"web-design-guidelines\":{\"version\":\"1\"},\"taste\":{\"version\":\"2\"}}}}}"
run_hook startup "$PROJ"
assert "fully active pack: silent" silent
fresh part
use_real
seed projects.json "{\"schema_version\":1,\"projects\":{\"$PROJ\":{\"tools\":{\"playwright\":{\"version\":\"0.1.22\"}}}}}"
run_hook startup "$PROJ"
assert "partly active pack: silent" silent
assert "partly active pack: no hints.json" no_hints_file
fresh other
use_real
seed projects.json "{\"schema_version\":1,\"projects\":{\"/elsewhere\":{\"tools\":{\"playwright\":{\"version\":\"0.1.22\"}}}}}"
run_hook startup "$PROJ"
assert "tool active in another project: still hints" msg_has "ai-pack add web"
fresh badpkg
use_real
printf '{ not json\n' >"$PROJ/package.json"
printf '<html></html>\n' >"$PROJ/index.html"
run_hook startup "$PROJ"
assert "corrupt package.json: silent" silent
assert "corrupt package.json: no hints.json" no_hints_file
fresh newer
use_real
seed hints.json '{"schema_version":99,"projects":{}}'
before=$(<"$STATE/hints.json")
run_hook startup "$PROJ"
assert "newer hints schema: silent" silent
assert "newer hints schema: file unchanged" file_is "$STATE/hints.json" "$before"
fresh corrupt
use_real
seed hints.json '{ nope'
run_hook startup "$PROJ"
assert "corrupt hints.json: silent" silent
assert "corrupt hints.json: left alone" file_is "$STATE/hints.json" "{ nope"
fresh resume
use_real
run_hook resume "$PROJ"
assert "source resume: silent" silent
run_hook clear "$PROJ"
assert "source clear: silent" silent
assert "other sources: nothing written" no_hints_file
fresh nocwd
use_real
OUT=$(printf '{"source":"startup"}' | env HOME="$HOME_DIR" XDG_STATE_HOME="$STATE_HOME" PATH="$BINDIR:$CLEAN_PATH" bash "$HOOK" 2>/dev/null)
CODE=$?
assert "input without cwd: silent" silent
fresh nodir
use_real
run_hook startup "$TMP_ROOT/does-not-exist"
assert "cwd that does not exist: silent" silent
OUT=$(printf 'not json' | env HOME="$HOME_DIR" XDG_STATE_HOME="$STATE_HOME" PATH="$BINDIR:$CLEAN_PATH" bash "$HOOK" 2>/dev/null)
CODE=$?
assert "garbage input: silent" silent

echo "== writes only hints.json"
fresh writes
use_real
mkdir -p "$PROJ/src"
printf 'x\n' >"$PROJ/src/a.js"
proj_before=$(snapshot "$PROJ")
run_hook startup "$PROJ"
proj_after=$(snapshot "$PROJ")
assert "hint was shown" msg_has "ai-pack add web"
assert "project tree is unchanged" test "$proj_before" = "$proj_after"
assert "state dir holds hints.json and the lock only" test "$(state_names)" = "hints.json lock "
assert "no data dir is created" test ! -e "$HOME_DIR/data"

echo "== concurrency"
fresh busy
use_real
mkdir -p "$STATE"
flock "$STATE/lock" sleep 4 &
holder=$!
sleep 0.3
run_hook startup "$PROJ"
assert "lock held: silent" silent
assert "lock held: nothing written" no_hints_file
kill "$holder" 2>/dev/null
wait "$holder" 2>/dev/null
for i in 1 2 3; do
  fresh "par$i"
  use_real
  for n in a b; do
    jq -nc --arg c "$PROJ" '{source: "startup", cwd: $c}' |
      env HOME="$HOME_DIR" XDG_STATE_HOME="$STATE_HOME" XDG_DATA_HOME="$HOME_DIR/data" PATH="$BINDIR:$CLEAN_PATH" \
        AI_PACK_NOW="$NOW" bash "$HOOK" >"$TMP_ROOT/par$i/out-$n" 2>/dev/null &
  done
  wait
  total=$(cat "$TMP_ROOT/par$i/out-a" "$TMP_ROOT/par$i/out-b" | rg -c systemMessage)
  assert "two parallel sessions (round $i): one hint" test "${total:-0}" -eq 1
done

echo "== failures stay silent"
fresh slow
stub 'sleep 5; printf "v1\tlate\n"'
start=$SECONDS
run_hook startup "$PROJ" PACK_HINT_TIMEOUT=1.5
assert "timeout: silent" silent
assert "timeout: returns within 3 seconds" test $((SECONDS - start)) -le 3
fresh patient
stub 'sleep 2; printf "v1\tlate\n"'
run_hook startup "$PROJ" PACK_HINT_TIMEOUT=5
assert "PACK_HINT_TIMEOUT widens the cut" msg_is late
fresh unknown
stub 'printf "v2\tfuture format\n"'
run_hook startup "$PROJ"
assert "unknown prefix: silent" silent
stub 'printf "future format without a prefix\n"'
run_hook startup "$PROJ"
assert "no prefix: silent" silent
fresh failing
stub 'printf "v1\tpartial\n"; exit 1'
run_hook startup "$PROJ"
assert "ai-pack fails: silent" silent
fresh missing
run_hook startup "$PROJ"
assert "binary missing: silent" silent
fresh stubok
stub 'printf "v1\tweb found: ai-pack add web\n"'
run_hook startup "$PROJ"
assert "stub with v1 prefix: prefix stripped, message passed through" msg_is "web found: ai-pack add web"
assert "stub with v1 prefix: systemMessage only" only_system_message
stub 'printf "v1\tfirst\nv2\tskipped\nv1\tsecond\n"'
run_hook startup "$PROJ"
assert "mixed prefixes: v1 lines kept, others dropped" msg_is "$(printf 'first\nsecond')"
stub 'printf "%s\n" "$*" >"'"$TMP_ROOT"'/args"; printf "v1\tx\n"'
run_hook startup "$PROJ"
assert "binary gets: hint --cwd <hook cwd>" file_is "$TMP_ROOT/args" "hint --cwd $PROJ"

echo "== binary lookup"
fresh fallback
mkdir -p "$HOME_DIR/fallbackbin"
ln -sf "$ROOT/bin/ai-pack" "$HOME_DIR/fallbackbin/ai-pack"
run_hook startup "$PROJ" XDG_BIN_HOME="$HOME_DIR/fallbackbin"
assert "XDG_BIN_HOME fallback: hint printed" msg_has "ai-pack add web"
fresh homefb
mkdir -p "$HOME_DIR/.local/bin"
ln -sf "$ROOT/bin/ai-pack" "$HOME_DIR/.local/bin/ai-pack"
OUT=$(jq -nc --arg c "$PROJ" '{source: "startup", cwd: $c}' |
  env -u XDG_BIN_HOME HOME="$HOME_DIR" XDG_STATE_HOME="$STATE_HOME" PATH="$BINDIR:$CLEAN_PATH" AI_PACK_NOW="$NOW" bash "$HOOK" 2>/dev/null)
CODE=$?
assert "default ~/.local/bin fallback: hint printed" msg_has "ai-pack add web"
fresh pathfirst
stub 'printf "v1\tfrom path\n"'
run_hook startup "$PROJ" XDG_BIN_HOME="$HOME_DIR/fallbackbin"
assert "PATH wins over the fallback" msg_has "from path"

echo "== missing dependencies"
# nodep TOOL: a PATH holding every executable of the system PATH except TOOL.
nodep() {
  local dir="$TMP_ROOT/no-$1" d f
  mkdir -p "$dir"
  IFS=: read -ra _ds <<<"$CLEAN_PATH"
  for d in "${_ds[@]}"; do
    for f in "$d"/*; do
      [[ -x $f && ! -d $f && ${f##*/} != "$1" && ! -e $dir/${f##*/} ]] && ln -s "$f" "$dir/${f##*/}"
    done
  done
  printf '%s\n' "$dir"
}
for missing in curl sha256sum jq; do
  fresh "no-$missing"
  nopath=$(nodep "$missing")
  ai_out=$(HOME="$HOME_DIR" XDG_STATE_HOME="$STATE_HOME" PATH="$nopath" AI_PACK_NOW="$NOW" \
    bash "$ROOT/bin/ai-pack" hint --cwd "$PROJ" 2>"$TMP_ROOT/err-$missing")
  ai_code=$?
  assert "ai-pack hint without $missing: exits 0" test "$ai_code" -eq 0
  assert "ai-pack hint without $missing: no stderr" test ! -s "$TMP_ROOT/err-$missing"
  if [[ $missing == jq ]]; then
    assert "ai-pack hint without $missing: no stdout" test -z "$ai_out"
  else
    assert "ai-pack hint without $missing: still hints" test -n "$ai_out"
  fi
done

echo "== opt-out"
fresh off
use_real
run_hook startup "$PROJ" AI_HOOKS_OFF=pack-hint
assert "AI_HOOKS_OFF=pack-hint: silent" silent
assert "AI_HOOKS_OFF=pack-hint: nothing written" no_hints_file

echo
if [[ $failures -gt 0 ]]; then
  echo "$failures case(s) failed"
  exit 1
fi
echo "All cases passed"
