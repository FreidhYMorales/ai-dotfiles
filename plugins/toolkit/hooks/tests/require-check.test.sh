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

# new_repo NAME: create an empty git repo the gate trusts and print its path.
new_repo() {
  local dir="$TMP_ROOT/$1"
  mkdir -p "$dir"
  git -C "$dir" init -q
  git -C "$dir" config require-check.trusted true
  printf '%s\n' "$dir"
}

# new_untrusted_repo NAME: like new_repo, without the opt-in.
new_untrusted_repo() {
  new_repo "$1" >/dev/null
  git -C "$TMP_ROOT/$1" config --unset require-check.trusted
  printf '%s\n' "$TMP_ROOT/$1"
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
# The hook's stdout and stderr are kept in $LAST_STDOUT and $LAST_STDERR.
LAST_STDOUT=""
LAST_STDERR=""
expect() {
  local expected=$1 label=$2 input=$3 actual errfile="$TMP_ROOT/stderr" outfile="$TMP_ROOT/stdout"
  shift 3
  printf '%s' "$input" | env "$@" bash "$HOOK" >"$outfile" 2>"$errfile"
  actual=$?
  LAST_STDOUT=$(<"$outfile")
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

# message_has REGEX JSON: the hook's systemMessage matches REGEX.
message_has() { jq -e --arg re "$1" '.systemMessage | test($re)' >/dev/null 2>&1 <<<"$2"; }

payload() { jq -n --arg cwd "$1" '{hook_event_name: "Stop", stop_hook_active: false, cwd: $cwd}'; }

echo "== skip branches (exit 0) =="

repo=$(new_repo active)
# shellcheck disable=SC2016 # $$ is make syntax, expanded by the recipe shell.
write_makefile "$repo" 'for i in $$(seq 1 100); do echo "line-$$i"; done' 'exit 1'
expect 0 'stop_hook_active with a red check does not block again' \
  "$(jq -n --arg cwd "$repo" '{stop_hook_active: true, cwd: $cwd}')"
assert 'second stop says make check is still red' message_has 'make check is still red' "$LAST_STDOUT"
assert 'second stop message has the failure tail' message_has 'line-100' "$LAST_STDOUT"

active_green=$(new_repo active-green)
write_makefile "$active_green" 'touch ran-check' 'true'
expect 0 'stop_hook_active with a green check passes' \
  "$(jq -n --arg cwd "$active_green" '{stop_hook_active: true, cwd: $cwd}')"
assert 'second stop with a green check stays silent' test -z "$LAST_STDOUT"
assert 'second stop still runs make check' test -e "$active_green/ran-check"

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

echo "== trust: only opted-in repos run make =="

# untrusted_makefile DIR: a failing check whose parse alone leaves ran-shell.
untrusted_makefile() {
  # shellcheck disable=SC2016 # $(shell) is make syntax, written literally.
  printf 'X := $(shell touch ran-shell)\ncheck:\n\ttouch ran-check\n\texit 1\n' >"$1/Makefile"
}
names_opt_in() { jq -e '.systemMessage | test("git config require-check.trusted true")' >/dev/null 2>&1 <<<"$1"; }

repo=$(new_untrusted_repo untrusted)
untrusted_makefile "$repo"
expect 0 'untrusted repo with a failing check does not block' "$(payload "$repo")"
assert 'untrusted repo says how to opt in' names_opt_in "$LAST_STDOUT"
assert 'untrusted repo runs no make, not even detection' test ! -e "$repo/ran-shell" -a ! -e "$repo/ran-check"

repo=$(new_untrusted_repo global-only)
untrusted_makefile "$repo"
global_config="$TMP_ROOT/global-trusted.gitconfig"
printf '[require-check]\n\ttrusted = true\n' >"$global_config"
expect 0 'a global-only opt-in does not trust the repo' "$(payload "$repo")" GIT_CONFIG_GLOBAL="$global_config"
assert 'global-only opt-in still says how to opt in' names_opt_in "$LAST_STDOUT"
assert 'global-only opt-in runs no make' test ! -e "$repo/ran-shell" -a ! -e "$repo/ran-check"

# A clone can ship a directory that looks like a git dir and trusts itself;
# a session whose cwd is inside it must not run its Makefile.
repo=$(new_untrusted_repo planted)
planted="$repo/evil"
mkdir -p "$planted/objects" "$planted/refs"
touch "$planted/objects/.keep" "$planted/refs/.keep"
printf 'ref: refs/heads/main\n' >"$planted/HEAD"
printf '[core]\n\trepositoryformatversion = 0\n\tbare = false\n\tworktree = .\n[require-check]\n\ttrusted = true\n' >"$planted/config"
untrusted_makefile "$planted"
expect 0 'a planted git dir inside a clone does not block' "$(payload "$planted")"
assert 'a planted git dir cannot trust itself to run make' test ! -e "$planted/ran-shell" -a ! -e "$planted/ran-check"

repo=$(new_untrusted_repo untrusted-nomakefile)
printf 'x\n' >"$repo/file.txt"
expect 0 'untrusted repo without a Makefile does not block' "$(payload "$repo")"
assert 'untrusted repo without a Makefile stays silent' test -z "$LAST_STDOUT"

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

echo "== /flow:pair red marker =="

# red_repo NAME: repo on branch story/03-x with a failing check and a committed
# red test; leaves an uncommitted edit so the hook would normally run.
red_repo() {
  local dir
  dir=$(new_repo "$1")
  git -C "$dir" checkout -qb story/03-x
  write_makefile "$dir" 'exit 1'
  printf 'red\n' >"$dir/red.test"
  commit_all "$dir"
  printf 'wip\n' >"$dir/wip.txt"
  printf '%s\n' "$dir"
}

# write_marker DIR BRANCH SHA: the marker /flow:pair writes while a test is red.
write_marker() {
  printf '%s\n%s\n' "$2" "$3" >"$(git -C "$1" rev-parse --path-format=absolute --git-path flow-pair-red)"
}

has_system_message() { jq -e '.systemMessage | test("flow:pair")' >/dev/null 2>&1 <<<"$1"; }

repo=$(red_repo marker-ok)
write_marker "$repo" story/03-x "$(git -C "$repo" rev-parse HEAD)"
expect 0 'marker for this branch and a sha in HEAD does not block' "$(payload "$repo")"
assert 'honoured marker reports a systemMessage' has_system_message "$LAST_STDOUT"

repo=$(red_repo marker-stale)
write_marker "$repo" story/03-x 0123456789abcdef0123456789abcdef01234567
expect 2 'marker whose sha is not in HEAD still blocks' "$(payload "$repo")"
assert 'stale marker reports no systemMessage' test -z "$LAST_STDOUT"

repo=$(red_repo marker-forgotten)
sha=$(git -C "$repo" rev-parse HEAD)
printf 'green\n' >"$repo/green.txt"
git -C "$repo" add green.txt
git -C "$repo" -c user.name=t -c user.email=t@t -c core.hooksPath=/dev/null commit -qm green
write_marker "$repo" story/03-x "$sha"
expect 2 'marker whose red commit is no longer HEAD still blocks' "$(payload "$repo")"
assert 'forgotten marker reports no systemMessage' test -z "$LAST_STDOUT"

repo=$(red_repo marker-branch)
write_marker "$repo" story/99-other "$(git -C "$repo" rev-parse HEAD)"
expect 2 'marker for another branch still blocks' "$(payload "$repo")"

repo=$(red_repo marker-orphan)
sha=$(git -C "$repo" rev-parse HEAD)
git -C "$repo" checkout -q --orphan story/03-x-rewritten
git -C "$repo" rm -rqf --cached . >/dev/null
write_marker "$repo" story/03-x-rewritten "$sha"
expect 2 'marker on the right branch whose sha left HEAD still blocks' "$(payload "$repo")"

# A linked worktree has its own git dir; the marker must be found there.
repo=$(red_repo marker-main)
sha=$(git -C "$repo" rev-parse HEAD)
git -C "$repo" checkout -q -b main-line
wt="$TMP_ROOT/marker-worktree"
git -C "$repo" worktree add -q "$wt" story/03-x
printf 'wip\n' >"$wt/wip.txt"
write_marker "$wt" story/03-x "$sha"
expect 0 'marker in a linked worktree git dir is honoured' "$(payload "$wt")"
expect 2 'worktree marker does not leak to the main checkout' "$(payload "$repo")"

echo "== check-fast tier =="

repo=$(new_repo fast-preferred)
printf 'check:\n\ttouch ran-check\ncheck-fast:\n\ttouch ran-fast\n' >"$repo/Makefile"
expect 0 'a passing check-fast exits 0' "$(payload "$repo")"
assert 'check-fast runs when the Makefile defines it' test -e "$repo/ran-fast"
assert 'make check does not run when check-fast exists' test ! -e "$repo/ran-check"

repo=$(new_repo fast-failing)
# shellcheck disable=SC2016 # $$ is make syntax, expanded by the recipe shell.
printf 'check:\n\ttrue\ncheck-fast:\n\tfor i in $$(seq 1 100); do echo "fast-$$i"; done\n\texit 1\n' >"$repo/Makefile"
expect 2 'a failing check-fast blocks' "$(payload "$repo")"
assert 'a failing check-fast names its target' \
  grep -q 'make check-fast failed — fix these before finishing:' <<<"$LAST_STDERR"
assert 'a failing check-fast shows the tail of its output' grep -q 'fast-100' <<<"$LAST_STDERR"

repo=$(new_repo fast-only)
printf 'check-fast:\n\ttouch ran-fast\n\texit 1\n' >"$repo/Makefile"
expect 2 'a Makefile with only check-fast still gates the stop' "$(payload "$repo")"
assert 'check-fast alone runs' test -e "$repo/ran-fast"

echo "== messages name the target =="

repo=$(new_untrusted_repo fast-untrusted)
printf 'check-fast:\n\texit 1\n' >"$repo/Makefile"
expect 0 'untrusted repo with check-fast does not block' "$(payload "$repo")"
assert 'untrusted message names both targets' message_has 'neither make check nor make check-fast was run' "$LAST_STDOUT"

repo=$(new_repo fast-still-red)
printf 'check-fast:\n\techo fast-red\n\texit 1\n' >"$repo/Makefile"
expect 0 'second stop with a red check-fast does not block again' \
  "$(jq -n --arg cwd "$repo" '{stop_hook_active: true, cwd: $cwd}')"
assert 'second stop says make check-fast is still red' message_has 'make check-fast is still red' "$LAST_STDOUT"

repo=$(red_repo fast-marker)
printf 'check-fast:\n\texit 1\n' >"$repo/Makefile"
git -C "$repo" add Makefile
git -C "$repo" -c user.name=t -c user.email=t@t -c core.hooksPath=/dev/null commit -qm fast
write_marker "$repo" story/03-x "$(git -C "$repo" rev-parse HEAD)"
expect 0 'red marker with check-fast does not block' "$(payload "$repo")"
assert 'red marker message names check-fast' message_has 'make check-fast is expected to fail' "$LAST_STDOUT"

# A stub `timeout` records its limit and reports a timeout (exit 124) at once.
stub="$TMP_ROOT/stub-timeout"
mkdir -p "$stub"
# shellcheck disable=SC2016 # $1 is the stub's own argument, written literally.
printf '#!/usr/bin/env bash\nprintf "%%s\\n" "$1" >"%s/limit"\nexit 124\n' "$stub" >"$stub/timeout"
chmod +x "$stub/timeout"
repo=$(new_repo fast-timeout)
printf 'check-fast:\n\ttrue\n' >"$repo/Makefile"
expect 2 'a check-fast timeout blocks' "$(payload "$repo")" PATH="$stub:$PATH"
assert 'check-fast runs under a 60 s limit' test "$(<"$stub/limit")" = 60
assert 'timeout message names check-fast and its limit' \
  grep -q 'make check-fast timed out after 60s' <<<"$LAST_STDERR"

repo=$(new_repo check-timeout)
write_makefile "$repo" 'true'
expect 2 'a check timeout blocks' "$(payload "$repo")" PATH="$stub:$PATH"
assert 'check keeps its 300 s limit' test "$(<"$stub/limit")" = 300

echo
if [[ $failures -gt 0 ]]; then
  echo "$failures case(s) failed"
  exit 1
fi
echo "All cases passed"
