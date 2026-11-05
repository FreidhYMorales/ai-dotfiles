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

if ((failures > 0)); then
  printf '%d case(s) failed\n' "$failures"
  exit 1
fi
echo 'All cases passed'
