#!/usr/bin/env bash
# Run every *.test.sh under plugins/ and scripts/; fail if any test file fails.
set -u
# shellcheck source=scripts/lib.sh
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

count=0
while IFS= read -r f; do
  [[ $f == plugins/*.test.sh || $f == scripts/*.test.sh ]] || continue
  [[ -f $ROOT/$f ]] || continue
  count=$((count + 1))
  if out=$(cd "$ROOT" && bash "$f" 2>&1); then
    ok "$f"
  else
    printf '%s\n' "$out" | tail -n 40 >&2
    err "test failed: $f"
  fi
done < <(repo_files)
[[ $count -eq 0 ]] && ok "no test files found"
finish tests
