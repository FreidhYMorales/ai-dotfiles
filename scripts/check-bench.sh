#!/usr/bin/env bash
# Validate the benchmark tasks when bench/ changed; otherwise say it skipped.
# Usage: scripts/check-bench.sh [ROOT]
set -u
# shellcheck source=scripts/lib.sh
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

# Uncommitted work, or commits the remote's main does not have yet.
changes=$(
  git -C "$ROOT" status --porcelain -- bench 2>/dev/null
  git -C "$ROOT" diff --name-only origin/main...HEAD -- bench 2>/dev/null
)
if [[ -z $changes ]]; then
  if git -C "$ROOT" rev-parse -q --verify origin/main >/dev/null 2>&1; then
    printf 'bench: skipped, no change under bench/\n'
  else
    printf 'bench: skipped, could not compare with origin/main\n'
  fi
  exit 0
fi

bash "$ROOT/bench/worker/validate.sh"
