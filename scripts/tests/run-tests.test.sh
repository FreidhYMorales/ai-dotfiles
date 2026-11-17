#!/usr/bin/env bash
# Integration test for scripts/run-tests.sh sharding: TEST_SHARD=K/N runs one
# share of the test files, the shares never overlap and together they cover
# every file; without TEST_SHARD every file runs.
# Run: bash scripts/tests/run-tests.test.sh
set -u

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
failures=0

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

# A fake repo with three test files; each one logs its own path when it runs.
REPO=$TMP/repo
mkdir -p "$REPO/plugins/p/tests" "$REPO/scripts/tests"
for f in plugins/p/tests/a.test.sh plugins/p/tests/b.test.sh scripts/tests/c.test.sh; do
  # $RUN_LOG expands when the fake test runs, not here.
  # shellcheck disable=SC2016
  printf '#!/usr/bin/env bash\necho %s >>"$RUN_LOG"\n' "$f" >"$REPO/$f"
done
git -C "$REPO" init -q
git -C "$REPO" add .

# ran SHARD: run run-tests.sh on the fake repo with TEST_SHARD=SHARD (empty:
# unset). Sets GOT (the sorted paths that ran), CODE and ERR.
ran() {
  local log=$TMP/log
  : >"$log"
  if [[ -n $1 ]]; then
    TEST_SHARD=$1 RUN_LOG=$log bash "$ROOT/scripts/run-tests.sh" "$REPO" >/dev/null 2>"$TMP/err"
  else
    env -u TEST_SHARD RUN_LOG="$log" bash "$ROOT/scripts/run-tests.sh" "$REPO" >/dev/null 2>"$TMP/err"
  fi
  CODE=$?
  ERR=$(<"$TMP/err")
  GOT=$(sort "$log")
}

ALL=$'plugins/p/tests/a.test.sh\nplugins/p/tests/b.test.sh\nscripts/tests/c.test.sh'

echo "== no TEST_SHARD: every file runs =="
ran ''
assert 'every file runs' test "$GOT" = "$ALL"
assert 'exit 0' test "$CODE" -eq 0

echo "== TEST_SHARD=1/2 and 2/2 split the files =="
ran 1/2
one=$GOT
code1=$CODE
ran 2/2
two=$GOT
code2=$CODE
assert 'shard 1/2 exits 0' test "$code1" -eq 0
assert 'shard 2/2 exits 0' test "$code2" -eq 0
count() { if [[ -z $1 ]]; then echo 0; else wc -l <<<"$1"; fi; }
assert 'the shards take 2 and 1 of the 3 files' test "$(count "$one")$(count "$two")" = 21 -o "$(count "$one")$(count "$two")" = 12
assert 'no file runs in both shards' test -z "$(comm -12 <(echo "$one") <(echo "$two"))"
assert 'together the shards run every file' test "$(sort <<<"$one"$'\n'"$two")" = "$ALL"

echo "== a test file does not inherit TEST_SHARD =="
# Tests that run run-tests.sh themselves (checks.test.sh) must see every file.
# shellcheck disable=SC2016
printf '#!/usr/bin/env bash\necho "seen:${TEST_SHARD:-none}" >>"$RUN_LOG"\n' >"$REPO/scripts/tests/c.test.sh"
ran 1/2
assert 'a file in shard 1/2 sees no TEST_SHARD' test "$GOT" = $'plugins/p/tests/a.test.sh\nseen:none'

echo "== a bad TEST_SHARD fails loudly =="
for bad in 3/2 0/2 x 1/0; do
  ran "$bad"
  assert "TEST_SHARD=$bad: no file runs" test -z "$GOT"
  assert "TEST_SHARD=$bad: exits non-zero" test "$CODE" -ne 0
  assert "TEST_SHARD=$bad: the error names TEST_SHARD" rg -qF TEST_SHARD <<<"$ERR"
done

# slow_repo NAME SPEC...: a fake repo at $TMP/NAME whose test files are
# scripts/tests/<file>.test.sh, one per SPEC "file:seconds[:exit]"; each sleeps
# that long, then exits with that status (default 0).
slow_repo() {
  local repo=$TMP/$1 spec f s e
  shift
  mkdir -p "$repo/scripts/tests"
  for spec in "$@"; do
    IFS=: read -r f s e <<<"$spec"
    printf '#!/usr/bin/env bash\nsleep %s\nexit %s\n' "$s" "${e:-0}" >"$repo/scripts/tests/$f.test.sh"
  done
  git -C "$repo" init -q
  git -C "$repo" add .
}

# report REPO [SHARD]: run run-tests.sh on REPO; set CODE and REPORT (the
# paths listed after "slowest test files:", in order) and fail any listed line
# without a time in seconds.
report() {
  local out
  out=$(TEST_SHARD=${2:-} bash "$ROOT/scripts/run-tests.sh" "$1" 2>/dev/null)
  CODE=$?
  local block
  # The report's lines are the indented ones after the header.
  block=$(awk 'f && /^  / ; /^slowest test files:$/ {f=1}' <<<"$out")
  REPORT=$(awk '{print $2}' <<<"$block")
  TIMED=$(rg -c '^  [0-9]+\.[0-9]s  scripts/tests/[a-z0-9]+\.test\.sh$' <<<"$block" || echo 0)
}

echo "== the five slowest test files are reported, slowest first =="
slow_repo seven s1:0 s2:0.3 s3:0.6 s4:0.9 s5:1.2 s6:1.5 s7:1.8
report "$TMP/seven"
assert 'lists the five slowest, slowest first' test "$REPORT" = $'scripts/tests/s7.test.sh\nscripts/tests/s6.test.sh\nscripts/tests/s5.test.sh\nscripts/tests/s4.test.sh\nscripts/tests/s3.test.sh'
assert 'each listed file shows its time in seconds' test "$TIMED" = 5
assert 'exit 0' test "$CODE" -eq 0

echo "== fewer than five files, one failing: every file is reported =="
slow_repo three f1:0.6 f2:0:1 f3:0.3
report "$TMP/three"
assert 'lists all three, slowest first' test "$REPORT" = $'scripts/tests/f1.test.sh\nscripts/tests/f3.test.sh\nscripts/tests/f2.test.sh'
assert 'each listed file shows its time in seconds' test "$TIMED" = 3
assert 'exit 1 is unchanged' test "$CODE" -eq 1

echo "== under TEST_SHARD only that shard's files are reported =="
# Files are taken in path order: shard 1/2 runs s1, s3, s5, s7.
report "$TMP/seven" 1/2
assert 'lists only shard 1/2 files, slowest first' test "$REPORT" = $'scripts/tests/s7.test.sh\nscripts/tests/s5.test.sh\nscripts/tests/s3.test.sh\nscripts/tests/s1.test.sh'
assert 'each listed file shows its time in seconds' test "$TIMED" = 4

if [[ $failures -gt 0 ]]; then
  printf '%d case(s) failed\n' "$failures"
  exit 1
fi
echo "All cases passed"
