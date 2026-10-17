#!/usr/bin/env bash
# Tests for bin/pi-box: try to escape the sandbox and check that every attempt
# fails. Run: bash scripts/tests/pi-box.test.sh
# Box commands are single-quoted on purpose: $HOME and friends must expand
# inside the sandbox, not here.
# shellcheck disable=SC2016
set -u

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SCRIPT="$ROOT/bin/pi-box"
failures=0

if ! command -v bwrap >/dev/null 2>&1 || ! bwrap --ro-bind / / true 2>/dev/null; then
  echo "SKIP  bubblewrap unavailable (or user namespaces disabled); pi-box tests not run"
  exit 0
fi

TMP_ROOT=$(mktemp -d)
trap 'rm -rf "$TMP_ROOT"' EXIT
export GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1

# A fake HOME with secrets next to the project, and a pi install to protect.
home="$TMP_ROOT/home"
project="$home/work/proj"
mkdir -p "$home/.ssh" "$home/.config/gh" "$home/.pi/agent" "$project/src" "$home/work/other"
printf 'PRIVATE KEY\n' >"$home/.ssh/id_test"
printf 'oauth_token: gho_x\n' >"$home/.config/gh/hosts.yml"
printf '{}\n' >"$home/.pi/agent/models.json"
printf 'neighbour\n' >"$home/work/other/notes.txt"
git -C "$project" init -q

# box DIR CMD: run CMD (a bash -c string) through pi-box from DIR.
LAST_OUTPUT=""
LAST_EXIT=0
box() {
  local dir=$1
  shift
  LAST_OUTPUT=$(cd "$dir" && env -u XDG_STATE_HOME HOME="$home" bash "$SCRIPT" -- bash -c "$1" 2>&1)
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

says() { [[ $LAST_OUTPUT == *"$1"* ]]; }
lacks() { [[ $LAST_OUTPUT != *"$1"* ]]; }

echo "== the project is writable =="

box "$project" 'echo ok >src/new.txt && pwd'
assert 'writes inside the project succeed' test -f "$project/src/new.txt"
assert 'the sandbox starts in the same directory' says "$project"

box "$project/src" 'echo ok >../from-subdir.txt'
assert 'a subdirectory opens the whole git project' test -f "$project/from-subdir.txt"

echo "== escapes fail =="

box "$project" 'echo pwned >"$HOME/escaped.txt"; echo pwned >../../escaped.txt; true'
assert 'writes to HOME never reach the host' test ! -e "$home/escaped.txt"
assert 'writes next to the project never reach the host' test ! -e "$home/work/escaped.txt"

box "$project" 'cat "$HOME/.ssh/id_test" "$HOME/.config/gh/hosts.yml" ../other/notes.txt 2>&1; true'
assert 'ssh keys are invisible' lacks 'PRIVATE KEY'
assert 'the GitHub token is invisible' lacks 'gho_x'
assert 'sibling projects are invisible' lacks 'neighbour'

box "$project" 'echo tampered >"$HOME/.pi/agent/models.json"; true'
assert 'pi config changes never reach the host' test "$(cat "$home/.pi/agent/models.json")" == '{}'
box "$project" 'cat "$HOME/.pi/agent/models.json"'
assert 'the pi config is readable' says '{}'

box "$project" 'echo x >/tmp/box-tmp-probe; ls /tmp'
assert '/tmp is private to the sandbox' test ! -e /tmp/box-tmp-probe

box "$project" 'echo x >/usr/box-probe 2>&1; echo "exit=$?"'
assert 'the system is read-only' says 'exit=1'

echo "== pi state =="

box "$project" 'echo "$PI_CODING_AGENT_SESSION_DIR"; echo s >"$PI_CODING_AGENT_SESSION_DIR/s.jsonl"'
assert 'sessions go to a writable pi-box state dir' \
  test -f "$home/.local/state/pi-box/sessions/s.jsonl"

echo "== outside git =="

plain="$home/plain"
mkdir -p "$plain"
box "$plain" 'echo ok >here.txt'
assert 'outside git the current folder is the project' test -f "$plain/here.txt"

echo "== refuses projects that would expose HOME =="

box "$home" 'echo pwned >"$HOME/.ssh/id_test"; true'
assert 'running from HOME is refused' test "$LAST_EXIT" -ne 0
assert 'the refusal explains why' says 'refusing'
assert 'nothing in HOME was touched' test "$(cat "$home/.ssh/id_test")" == 'PRIVATE KEY'

box / 'true'
assert 'running from / is refused' test "$LAST_EXIT" -ne 0

echo
if [[ $failures -gt 0 ]]; then
  echo "$failures case(s) failed"
  exit 1
fi
echo "All cases passed"
