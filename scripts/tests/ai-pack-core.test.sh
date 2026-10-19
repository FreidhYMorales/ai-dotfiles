#!/usr/bin/env bash
# Tests for the ai-pack core: project key, dependency check, state files,
# tree hash and ignore. Run: bash scripts/tests/ai-pack-core.test.sh
# Black box through bin/ai-pack; pure helpers are sourced from packs/lib.
# jq filters are single-quoted on purpose: $k is a jq variable.
# shellcheck disable=SC2016
set -u

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SCRIPT="$ROOT/bin/ai-pack"
failures=0
TMP_ROOT=$(realpath "$(mktemp -d)")
trap 'chmod -R u+rwx "$TMP_ROOT" 2>/dev/null; rm -rf "$TMP_ROOT"' EXIT

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

LAST_OUTPUT=""
LAST_EXIT=0
# pack [ARGS...]: run ai-pack with state in $STATE; output in $LAST_OUTPUT.
pack() {
  LAST_OUTPUT=$(AI_PACK_STATE="$STATE" bash "$SCRIPT" "$@" 2>&1)
  LAST_EXIT=$?
}

says() { [[ $LAST_OUTPUT == *"$1"* ]]; }
json_ok() {
  local f=$1
  shift
  jq -e "$@" "$f" >/dev/null 2>&1
}
exit_is() { [[ $LAST_EXIT -eq $1 ]]; }
fresh_state() { STATE="$TMP_ROOT/state-$1"; }

git_q() { git -c user.name=t -c user.email=t@t -c commit.gpgsign=false "$@"; }

echo "== project key =="

repo="$TMP_ROOT/repo"
mkdir -p "$repo/sub/deep"
git_q init -q "$repo" && git_q -C "$repo" commit -q --allow-empty -m init
git_q -C "$repo" worktree add -q "$TMP_ROOT/wt" -b other
ln -s "$repo/sub/deep" "$TMP_ROOT/link"
mkdir "$TMP_ROOT/plain"

fresh_state key
key_of() { # DIR [ARGS...]: run `ignore web` and print the single key it stored
  rm -rf "$STATE"
  (cd "$1" && shift && AI_PACK_STATE="$STATE" bash "$SCRIPT" ignore web "$@" >/dev/null 2>&1)
  jq -r '.projects | keys[0]' "$STATE/ignored.json"
}
assert 'git root from the root' test "$(key_of "$repo")" = "$repo"
assert 'git root from a subdirectory' test "$(key_of "$repo/sub/deep")" = "$repo"
assert 'absolute --cwd' test "$(key_of "$TMP_ROOT" --cwd "$repo/sub")" = "$repo"
assert 'relative --cwd' test "$(key_of "$repo" --cwd sub/../sub/deep)" = "$repo"
assert 'symlinked path resolves to the real root' test "$(key_of "$TMP_ROOT/link")" = "$repo"
assert 'second worktree has its own key' test "$(key_of "$TMP_ROOT/wt")" = "$TMP_ROOT/wt"
assert 'non-git directory uses the cwd' test "$(key_of "$TMP_ROOT/plain")" = "$TMP_ROOT/plain"
assert 'GIT_DIR in the env is ignored' test \
  "$(GIT_DIR="$TMP_ROOT/wt/.git" key_of "$repo/sub")" = "$repo"

echo "== dependency check =="

# bin_without CMD: a PATH dir with the tools ai-pack needs, minus CMD.
bin_without() {
  local d="$TMP_ROOT/bin-no-$1" c
  mkdir -p "$d"
  for c in jq flock curl sha256sum bash env dirname readlink realpath git mktemp mkdir mv rm \
    sort find stat cat awk head chmod cp; do
    [[ $c == "$1" ]] || ln -sf "$(command -v "$c")" "$d/$c"
  done
  printf '%s\n' "$d"
}
fresh_state deps
LAST_OUTPUT=$(PATH=$(bin_without jq) AI_PACK_STATE="$STATE" bash "$SCRIPT" ignore web 2>&1)
LAST_EXIT=$?
assert 'missing jq exits 1' exit_is 1
assert 'missing jq prints the pacman line' says 'sudo pacman -S jq'
assert 'missing jq writes nothing' test ! -e "$STATE"
LAST_OUTPUT=$(PATH=$(bin_without flock) AI_PACK_STATE="$STATE" bash "$SCRIPT" ignore web 2>&1)
assert 'missing flock names its package' says 'sudo pacman -S util-linux'

echo "== state files =="

fresh_state schema
mkdir -p "$STATE"
printf '{"schema_version":2,"projects":{"x":["old"]}}' >"$STATE/ignored.json"
pack ignore web --cwd "$TMP_ROOT/plain"
assert 'newer schema refuses' exit_is 1
assert 'newer schema says why' says 'newer'
assert 'newer schema leaves the file alone' json_ok "$STATE/ignored.json" \
  '.schema_version == 2 and .projects == {"x": ["old"]}'

printf '{"schema_version":0}' >"$STATE/ignored.json"
pack ignore web --cwd "$TMP_ROOT/plain"
assert 'older schema uses defaults' exit_is 0
assert 'older schema is rewritten at version 1' json_ok "$STATE/ignored.json" \
  --arg k "$TMP_ROOT/plain" '.schema_version == 1 and .projects[$k] == ["web"]'

printf 'not json' >"$STATE/ignored.json"
pack ignore web --cwd "$TMP_ROOT/plain"
assert 'corrupt state refuses' exit_is 1
assert 'corrupt state is not overwritten' test "$(<"$STATE/ignored.json")" = 'not json'

rm "$STATE/ignored.json"
(flock "$STATE/lock" sleep 3) &
sleep 0.5
LAST_OUTPUT=$(AI_PACK_LOCK_WAIT=1 AI_PACK_STATE="$STATE" bash "$SCRIPT" ignore web --cwd "$TMP_ROOT/plain" 2>&1)
LAST_EXIT=$?
assert 'a held lock times out' exit_is 1
assert 'a held lock says so' says 'lock'
assert 'a held lock writes nothing' test ! -e "$STATE/ignored.json"
wait

# shellcheck source=packs/lib/common.sh
source "$ROOT/packs/lib/common.sh"
# shellcheck source=packs/lib/state.sh
source "$ROOT/packs/lib/state.sh"
# shellcheck source=packs/lib/tree.sh
source "$ROOT/packs/lib/tree.sh"
STATE_DIR=$STATE
lock_try
assert 'lock_try takes a free lock' test $? -eq 0
exec 9>&-
(flock "$STATE/lock" sleep 2) &
sleep 0.5
(lock_try)
assert 'lock_try fails on a held lock' test $? -ne 0
wait

echo "== version_ge =="
assert '22.1.0 >= 22' version_ge 22.1.0 22
assert 'equal versions' version_ge 0.1.22 0.1.22
assert '0.1.23 >= 0.1.22' version_ge 0.1.23 0.1.22
assert '10 >= 9 is numeric' version_ge 10 9
assert '21.9 < 22' bash -c '! { source "$1" && version_ge 21.9 22; }' _ "$ROOT/packs/lib/common.sh"

echo "== tree hash =="

mk_tree() { # DIR: a small tree with a script, a link and a nested file
  mkdir -p "$1/sub"
  printf 'hello\n' >"$1/a.txt"
  printf '#!/bin/sh\n' >"$1/run.sh"
  chmod u+x "$1/run.sh"
  printf 'deep\n' >"$1/sub/b.txt"
  ln -s a.txt "$1/link"
}
hash_of() { pack hash "$1" && printf '%s' "$LAST_OUTPUT"; }

mkdir "$TMP_ROOT/empty"
assert 'empty dir hashes the empty stream' test "$(hash_of "$TMP_ROOT/empty")" = \
  'sha256:e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855'

mkdir "$TMP_ROOT/one"
printf 'hi' >"$TMP_ROOT/one/a"
want=$(printf '%s\0%s\0%s\0%s\n' f 0 ./a "$(printf hi | sha256sum | cut -d' ' -f1)" | sha256sum | cut -d' ' -f1)
assert 'one file matches the documented line format' test "$(hash_of "$TMP_ROOT/one")" = "sha256:$want"

(umask 022 && mk_tree "$TMP_ROOT/t022")
(umask 077 && mk_tree "$TMP_ROOT/t077")
base=$(hash_of "$TMP_ROOT/t022")
assert 'hash is deterministic across umasks' test "$(hash_of "$TMP_ROOT/t077")" = "$base"
assert 'hash prints sha256: and 64 hex chars' [ "${#base}" -eq 71 ]

echo gi >"$TMP_ROOT/t022/.gitignore"
assert 'top-level .gitignore is excluded' test "$(hash_of "$TMP_ROOT/t022")" = "$base"
echo gi >"$TMP_ROOT/t022/sub/.gitignore"
assert 'a nested .gitignore is hashed' test "$(hash_of "$TMP_ROOT/t022")" != "$base"
rm "$TMP_ROOT/t022/sub/.gitignore"

printf 'changed\n' >"$TMP_ROOT/t022/a.txt"
assert 'content change alters the hash' test "$(hash_of "$TMP_ROOT/t022")" != "$base"
printf 'hello\n' >"$TMP_ROOT/t022/a.txt"
chmod u+x "$TMP_ROOT/t022/a.txt"
assert 'exec bit alters the hash' test "$(hash_of "$TMP_ROOT/t022")" != "$base"
chmod u-x "$TMP_ROOT/t022/a.txt"
ln -sfn sub/b.txt "$TMP_ROOT/t022/link"
assert 'link target alters the hash' test "$(hash_of "$TMP_ROOT/t022")" != "$base"
ln -sfn a.txt "$TMP_ROOT/t022/link"
assert 'restoring the tree restores the hash' test "$(hash_of "$TMP_ROOT/t022")" = "$base"

pack hash "$TMP_ROOT/missing"
assert 'hash of a missing dir fails' exit_is 1

normalize_modes "$TMP_ROOT/t077"
assert 'normalize_modes sets dirs 755, files 644, scripts 755' test \
  "$(stat -c %a "$TMP_ROOT/t077/sub") $(stat -c %a "$TMP_ROOT/t077/a.txt") $(stat -c %a "$TMP_ROOT/t077/run.sh")" = '755 644 755'

echo "== ignore =="

fresh_state ign
pack ignore web --cwd "$TMP_ROOT/plain"
assert 'ignore exits 0' exit_is 0
assert 'ignore records the pack' json_ok "$STATE/ignored.json" --arg k "$TMP_ROOT/plain" \
  '.schema_version == 1 and .projects[$k] == ["web"]'
pack ignore web --cwd "$TMP_ROOT/plain"
pack ignore diagrams --cwd "$TMP_ROOT/plain"
assert 'ignore is idempotent and sorted' json_ok "$STATE/ignored.json" --arg k "$TMP_ROOT/plain" \
  '.projects[$k] == ["diagrams", "web"]'
pack ignore web --cwd "$repo"
pack unignore web --cwd "$TMP_ROOT/plain"
assert 'unignore clears only that pack for that project' json_ok "$STATE/ignored.json" \
  --arg k "$TMP_ROOT/plain" --arg r "$repo" '.projects[$k] == ["diagrams"] and .projects[$r] == ["web"]'
pack unignore diagrams --cwd "$TMP_ROOT/plain"
assert 'unignore drops an emptied project' json_ok "$STATE/ignored.json" --arg k "$TMP_ROOT/plain" \
  '.projects | has($k) | not'
pack ignore
assert 'ignore without a pack is a usage error' exit_is 2
pack frobnicate
assert 'unknown command is a usage error' exit_is 2

if [[ $failures -gt 0 ]]; then
  printf '%d failure(s)\n' "$failures" >&2
  exit 1
fi
echo "all passed"
