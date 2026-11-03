#!/usr/bin/env bash
# Run every *.test.sh under plugins/ and scripts/; fail if any test file fails.
# Files run in parallel (each test isolates itself in its own temp dirs);
# results are reported in file order so the output stays stable.
set -u
# shellcheck source=scripts/lib.sh
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

files=()
while IFS= read -r f; do
  [[ $f == plugins/*.test.sh || $f == scripts/*.test.sh ]] || continue
  [[ -f $ROOT/$f ]] && files+=("$f")
done < <(repo_files)

# TEST_SHARD=K/N (CI) keeps every Nth file starting at the Kth, so N jobs
# split the files with no overlap.
if [[ -n ${TEST_SHARD:-} ]]; then
  if [[ ! $TEST_SHARD =~ ^([1-9][0-9]*)/([1-9][0-9]*)$ ]] || ((BASH_REMATCH[1] > BASH_REMATCH[2])); then
    err "TEST_SHARD must be K/N with 1 <= K <= N, got '$TEST_SHARD'"
    finish tests
  fi
  k=${BASH_REMATCH[1]} n=${BASH_REMATCH[2]}
  # Tests that run run-tests.sh themselves must see every file.
  export -n TEST_SHARD
  shard=()
  for i in "${!files[@]}"; do
    ((i % n == k - 1)) && shard+=("${files[i]}")
  done
  files=("${shard[@]}")
fi

if [[ ${#files[@]} -eq 0 ]]; then
  ok "no test files found"
  finish tests
fi

results=$(mktemp -d)
trap 'rm -rf "$results"' EXIT
pids=()
for i in "${!files[@]}"; do
  (
    cd "$ROOT" && bash "${files[i]}" >"$results/$i.out" 2>&1
    echo $? >"$results/$i.status"
  ) &
  pids+=($!)
done
wait "${pids[@]}"

for i in "${!files[@]}"; do
  if [[ $(<"$results/$i.status") == 0 ]]; then
    ok "${files[i]}"
  else
    tail -n 40 "$results/$i.out" >&2
    err "test failed: ${files[i]}"
  fi
done
finish tests
