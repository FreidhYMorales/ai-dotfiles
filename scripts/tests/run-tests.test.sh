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

echo "== a bad TEST_SHARD fails loudly =="
for bad in 3/2 0/2 x 1/0; do
  ran "$bad"
  assert "TEST_SHARD=$bad: no file runs" test -z "$GOT"
  assert "TEST_SHARD=$bad: exits non-zero" test "$CODE" -ne 0
  assert "TEST_SHARD=$bad: the error names TEST_SHARD" rg -qF TEST_SHARD <<<"$ERR"
done

if [[ $failures -gt 0 ]]; then
  printf '%d case(s) failed\n' "$failures"
  exit 1
fi
echo "All cases passed"
