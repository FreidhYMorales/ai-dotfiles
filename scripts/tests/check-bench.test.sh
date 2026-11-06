#!/usr/bin/env bash
# Tests for the bench step of `make check`: it validates the benchmark tasks only
# when bench/ changed. Each case builds a throwaway repo holding the real
# validate.sh and tiny tasks, so no model and no private repo is involved.
# Run: bash scripts/tests/check-bench.test.sh
set -u

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
failures=0
TMP_ROOT=$(realpath "$(mktemp -d)")
trap 'rm -rf "$TMP_ROOT"' EXIT

# Isolate git from the user's config and hooks.
mkdir -p "$TMP_ROOT/home"
export HOME="$TMP_ROOT/home" GIT_CONFIG_NOSYSTEM=1 GIT_CONFIG_GLOBAL="$TMP_ROOT/home/gitconfig"
git config --file "$GIT_CONFIG_GLOBAL" user.name t
git config --file "$GIT_CONFIG_GLOBAL" user.email t@t
git config --file "$GIT_CONFIG_GLOBAL" commit.gpgsign false
git config --file "$GIT_CONFIG_GLOBAL" init.defaultBranch main

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

# mk_task REPO NAME: a task that fails on base and passes with its patch.
mk_task() {
  local dir=$1/bench/worker/tasks/$2
  mkdir -p "$dir/fixture"
  printf 'x\n' >"$dir/fixture/README"
  printf 'Create done.\n' >"$dir/prompt.md"
  printf 'test -f done\n' >"$dir/check.sh"
  printf 'done\n' >"$dir/allowed"
  printf 'bash\n' >"$dir/lang"
  printf 'L1\n' >"$dir/level"
  printf 'fixture\n' >"$dir/source"
  cat >"$dir/reference.patch" <<'PATCH'
diff --git a/done b/done
new file mode 100644
--- /dev/null
+++ b/done
@@ -0,0 +1 @@
+x
PATCH
}

# mk_repo NAME: a repo whose origin/main is its HEAD, with one valid task.
mk_repo() {
  R=$TMP_ROOT/$1
  mkdir -p "$R/bench/worker"
  cp "$ROOT/bench/worker/validate.sh" "$ROOT/bench/worker/lib.sh" "$ROOT/bench/worker/BASE" "$R/bench/worker/"
  mk_task "$R" good-task
  git -C "$R" init -q
  git -C "$R" add -A
  git -C "$R" commit -q -m init
  git -C "$R" update-ref refs/remotes/origin/main HEAD
}

OUTPUT=""
# run_check: the whole of scripts/check.sh on $R; only the bench step's lines
# land in $OUTPUT, and the summary's failure line in $FAILED_LINE.
run_check() {
  local all
  all=$(bash "$ROOT/scripts/check.sh" "$R" 2>&1)
  OUTPUT=$(awk '/^== bench ==$/ {on = 1; print; next} /^== / {on = 0} on' <<<"$all")
  FAILED_LINE=$(grep -F 'FAILED: bench' <<<"$all")
}
says() { [[ $OUTPUT == *"$1"* ]]; }
lacks() { ! says "$1"; }

echo "== no change under bench/ =="
mk_repo clean
run_check
assert 'the bench step ran' says '== bench =='
assert 'it says the validation was skipped' says 'skipped'
assert 'it validates no task' lacks 'good-task'
assert 'it does not fail' test -z "$FAILED_LINE"

echo "== an uncommitted change under bench/ =="
mk_repo dirty
printf 'Create done now.\n' >"$R/bench/worker/tasks/good-task/prompt.md"
run_check
assert 'the task is validated' says 'ok    good-task'
assert 'the validation reports its total' says 'All 1 task(s) valid'
assert 'it no longer says skipped' lacks 'skipped'
assert 'a valid task does not fail the step' test -z "$FAILED_LINE"

echo "== an unpushed commit under bench/, clean tree =="
mk_repo unpushed
printf 'Create done now.\n' >"$R/bench/worker/tasks/good-task/prompt.md"
git -C "$R" commit -q -am 'change a task'
run_check
assert 'the unpushed change validates the task' says 'ok    good-task'
assert 'the unpushed change is not skipped' lacks 'skipped'

echo "== a task that fails validation =="
mk_repo broken
mk_task "$R" broken-task
# A check that passes on the untouched repo proves nothing, so validation fails.
printf 'true\n' >"$R/bench/worker/tasks/broken-task/check.sh"
run_check
assert 'the step names the broken task' says 'FAIL  broken-task'
assert 'the other task is still validated' says 'ok    good-task'
assert 'make check reports the bench step failed' test -n "$FAILED_LINE"

echo "== no origin/main, clean tree (a pull request checkout in CI) =="
mk_repo noremote
git -C "$R" update-ref -d refs/remotes/origin/main
run_check
assert 'with no origin/main it says skipped' says 'skipped'
assert 'with no origin/main it validates no task' lacks 'good-task'
assert 'with no origin/main it prints no git error' lacks 'fatal'
assert 'with no origin/main it does not fail' test -z "$FAILED_LINE"
assert 'with no origin/main it says it could not compare' says 'could not compare'
assert 'with no origin/main it does not claim no change' lacks 'no change'

echo "== a task whose source repo is not on this machine =="
mk_repo away
mk_task "$R" away-task
rm -rf "$R/bench/worker/tasks/away-task/fixture"
printf '%s abc1234\n' "$TMP_ROOT/no-such-repo" >"$R/bench/worker/tasks/away-task/source"
run_check
assert 'the task is reported as skipped' says 'SKIP  away-task'
assert 'the report names the missing repo' says "$TMP_ROOT/no-such-repo"
assert 'the other task is validated' says 'ok    good-task'
assert 'the summary counts the valid and the skipped' says 'All 1 task(s) valid, 1 skipped'
assert 'the missing repo alone does not fail the step' test -z "$FAILED_LINE"

echo "== a source repo that is here, without the task's commit =="
mk_repo here
mk_task "$R" here-task
rm -rf "$R/bench/worker/tasks/here-task/fixture"
source_repo=$TMP_ROOT/here-source
git init -q "$source_repo"
git -C "$source_repo" commit -q --allow-empty -m init
printf '%s abc1234\n' "$source_repo" >"$R/bench/worker/tasks/here-task/source"
run_check
assert 'the task fails' says 'FAIL  here-task'
assert 'the task is not skipped' lacks 'SKIP  here-task'
assert 'make check reports the failure' test -n "$FAILED_LINE"

echo "== changes outside bench/ =="
mk_repo outside-dirty
printf 'x\n' >"$R/other"
run_check
assert 'an uncommitted change elsewhere says skipped' says 'skipped'
assert 'an uncommitted change elsewhere validates no task' lacks 'good-task'

mk_repo outside-unpushed
printf 'x\n' >"$R/other"
git -C "$R" add other
git -C "$R" commit -q -m 'change elsewhere'
run_check
assert 'an unpushed commit elsewhere says skipped' says 'skipped'
assert 'an unpushed commit elsewhere validates no task' lacks 'good-task'

echo "== a branch behind origin/main, whose new commit changed bench/ =="
mk_repo behind
printf 'Create done now.\n' >"$R/bench/worker/tasks/good-task/prompt.md"
git -C "$R" commit -q -am 'the remote changes a task'
git -C "$R" update-ref refs/remotes/origin/main HEAD
git -C "$R" reset -q --hard HEAD~1
run_check
assert 'a branch behind the remote says skipped' says 'skipped'
assert 'a branch behind the remote validates no task' lacks 'good-task'

echo "== an exported GIT_DIR, as a hook in a linked worktree sets =="
# Git reads GIT_DIR before -C, so the tasks must not act on the checked repo.
mk_repo gitdir
mk_task "$R" cloned-task
rm -rf "$R/bench/worker/tasks/cloned-task/fixture"
# Its own commit: under GIT_DIR a commit from another repo stops `checkout -B`
# before the code that switches the branch and deletes refs gets to run.
printf '%s %s\n' "$R" "$(git -C "$R" rev-parse HEAD)" \
  >"$R/bench/worker/tasks/cloned-task/source"
git -C "$R" add -A
git -C "$R" commit -q -m 'add a task cloned from this repo'
git -C "$R" branch keep-me
head=$(git -C "$R" rev-parse HEAD)
OUTPUT=$(GIT_DIR="$R/.git" bash "$ROOT/scripts/check-bench.sh" "$R" 2>&1)
assert 'the fixture task is validated' says 'ok    good-task'
assert 'the cloned task is validated' says 'ok    cloned-task'
assert 'HEAD of the checked repo does not move' test "$(git -C "$R" rev-parse HEAD)" = "$head"
assert 'the branch of the checked repo stays' test "$(git -C "$R" branch --show-current)" = main
assert 'the other branch of the checked repo survives' git -C "$R" rev-parse -q --verify refs/heads/keep-me

if ((failures > 0)); then
  printf '%d case(s) failed\n' "$failures"
  exit 1
fi
echo 'All cases passed'
