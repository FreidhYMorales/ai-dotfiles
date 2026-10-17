#!/usr/bin/env bash
# Tests for require-check.sh. Run: bash plugins/toolkit/hooks/tests/require-check.test.sh
set -u

HOOK="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/require-check.sh"
failures=0
TMP_ROOT=$(mktemp -d)
trap 'rm -rf "$TMP_ROOT"' EXIT

# Isolate fixture repos from the user's global git config and hooks.
export GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1
unset SKIP_REQUIRE_CHECK
# Isolate the green-state cache from the real ~/.cache.
export XDG_CACHE_HOME="$TMP_ROOT/cache"

# new_repo NAME: create an empty git repo and print its path.
new_repo() {
  local dir="$TMP_ROOT/$1"
  mkdir -p "$dir"
  git -C "$dir" init -q
  printf '%s\n' "$dir"
}

# commit_all DIR: commit everything so the working tree is clean.
commit_all() {
  git -C "$1" add -A
  git -C "$1" -c user.name=t -c user.email=t@t -c core.hooksPath=/dev/null \
    commit -qm init
}

# write_makefile DIR RECIPE...: Makefile with a check target running RECIPE lines.
write_makefile() {
  local dir=$1 line
  shift
  printf 'check:\n' >"$dir/Makefile"
  for line in "$@"; do printf '\t%s\n' "$line" >>"$dir/Makefile"; done
}

# expect EXPECTED_EXIT LABEL STDIN [ENV...]: run the hook and compare its exit code.
# The hook's stderr is kept in $LAST_STDERR for content assertions.
LAST_STDERR=""
expect() {
  local expected=$1 label=$2 input=$3 actual errfile="$TMP_ROOT/stderr"
  shift 3
  printf '%s' "$input" | env "$@" bash "$HOOK" >/dev/null 2>"$errfile"
  actual=$?
  LAST_STDERR=$(<"$errfile")
  if [[ $actual -eq $expected ]]; then
    printf 'PASS  [exit %d] %s\n' "$actual" "$label"
  else
    printf 'FAIL  [want %d, got %d] %s\n' "$expected" "$actual" "$label"
    failures=$((failures + 1))
  fi
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

lacks_line() { ! grep -qx "$1" <<<"$2"; }

payload() { jq -n --arg cwd "$1" '{hook_event_name: "Stop", stop_hook_active: false, cwd: $cwd}'; }

echo "== skip branches (exit 0) =="

repo=$(new_repo active)
write_makefile "$repo" 'exit 1'
expect 0 'stop_hook_active true skips' \
  "$(jq -n --arg cwd "$repo" '{stop_hook_active: true, cwd: $cwd}')"

expect 0 'SKIP_REQUIRE_CHECK=1 skips' "$(payload "$repo")" SKIP_REQUIRE_CHECK=1

notgit="$TMP_ROOT/notgit"
mkdir -p "$notgit"
write_makefile "$notgit" 'exit 1'
expect 0 'cwd outside a git repo skips' "$(payload "$notgit")"
expect 0 'nonexistent cwd skips' "$(payload "$TMP_ROOT/does-not-exist")"

repo=$(new_repo clean)
write_makefile "$repo" 'exit 1'
commit_all "$repo"
expect 0 'clean working tree skips' "$(payload "$repo")"

repo=$(new_repo nomakefile)
printf 'x\n' >"$repo/file.txt"
expect 0 'no Makefile skips' "$(payload "$repo")"

repo=$(new_repo nocheck)
printf 'other:\n\t+touch ran-other\nall:\n\t+touch ran-all\n' >"$repo/Makefile"
expect 0 'Makefile without check target skips' "$(payload "$repo")"
assert 'detection executes no recipe' test ! -e "$repo/ran-other" -a ! -e "$repo/ran-all"

repo=$(new_repo empty-stdin)
write_makefile "$repo" 'exit 1'
pushd "$repo" >/dev/null || exit 1
expect 2 'empty stdin falls back to PWD' ''
popd >/dev/null || exit 1

echo "== run make check =="

repo=$(new_repo passing)
write_makefile "$repo" 'touch ran-check' 'true'
expect 0 'passing check exits 0' "$(payload "$repo")"
assert 'check target actually ran' test -e "$repo/ran-check"

repo=$(new_repo gnumakefile)
printf 'check:\n\ttrue\n' >"$repo/GNUmakefile"
expect 0 'GNUmakefile with passing check exits 0' "$(payload "$repo")"

repo=$(new_repo failing)
# shellcheck disable=SC2016 # $$ is make syntax, expanded by the recipe shell.
write_makefile "$repo" 'for i in $$(seq 1 100); do echo "line-$$i"; done' 'exit 1'
expect 2 'failing check exits 2' "$(payload "$repo")"
assert 'stderr has failure header' \
  grep -q 'make check failed — fix these before finishing:' <<<"$LAST_STDERR"
assert 'stderr has tail of output' grep -q 'line-100' <<<"$LAST_STDERR"
assert 'stderr omits head of long output' lacks_line 'line-1' "$LAST_STDERR"

repo=$(new_repo subdir)
write_makefile "$repo" 'exit 1'
mkdir -p "$repo/src"
expect 2 'cwd in subdir runs the repo-root check' "$(payload "$repo/src")"

repo=$(new_repo subdir-pass)
write_makefile "$repo" 'test -f Makefile'
mkdir -p "$repo/src"
expect 0 'repo-root check runs from the repo root' "$(payload "$repo/src")"

echo "== green-state cache =="

# runs FILE: how many times the check recipe ran (it appends to FILE, which
# lives outside the repo so counting does not change the working tree).
runs() { wc -l <"$1" 2>/dev/null || echo 0; }

repo=$(new_repo cache-hit)
counter="$TMP_ROOT/cache-hit.count"
write_makefile "$repo" "echo run >>$counter"
printf 'x\n' >"$repo/file.txt"
expect 0 'first run passes' "$(payload "$repo")"
expect 0 'unchanged tree passes again' "$(payload "$repo")"
assert 'unchanged tree since the last green run skips make check' test "$(runs "$counter")" -eq 1

printf 'y\n' >"$repo/file.txt"
expect 0 'edited tree passes' "$(payload "$repo")"
assert 'an edited file reruns make check' test "$(runs "$counter")" -eq 2

printf 'z\n' >"$repo/new.txt"
expect 0 'tree with a new file passes' "$(payload "$repo")"
assert 'a new untracked file reruns make check' test "$(runs "$counter")" -eq 3

git -C "$repo" add new.txt
expect 0 'staged tree passes' "$(payload "$repo")"
printf 'w\n' >"$repo/new.txt"
git -C "$repo" add new.txt
expect 0 'restaged tree passes' "$(payload "$repo")"
assert 'a different staged version reruns make check' test "$(runs "$counter")" -eq 5

repo=$(new_repo cache-fail)
counter="$TMP_ROOT/cache-fail.count"
write_makefile "$repo" "echo run >>$counter" 'exit 1'
expect 2 'failing check blocks' "$(payload "$repo")"
expect 2 'failing check blocks again' "$(payload "$repo")"
assert 'a failing run is never cached' test "$(runs "$counter")" -eq 2

echo
if [[ $failures -gt 0 ]]; then
  echo "$failures case(s) failed"
  exit 1
fi
echo "All cases passed"
