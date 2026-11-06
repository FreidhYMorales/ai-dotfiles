#!/usr/bin/env bash
# Validate the benchmark tasks when bench/ changed; otherwise say it skipped.
# Usage: scripts/check-bench.sh [ROOT]
set -u
# shellcheck source=scripts/lib.sh
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

# Uncommitted work, or commits the remote's main does not have yet.
reason='no change under bench/'
uncommitted=$(git -C "$ROOT" status --porcelain -- bench 2>/dev/null)
unpushed=$(git -C "$ROOT" diff --name-only origin/main...HEAD -- bench 2>/dev/null) ||
  reason='could not compare with origin/main'
if [[ -z $uncommitted$unpushed ]]; then
  printf 'bench: skipped, %s\n' "$reason"
  exit 0
fi

bash "$ROOT/bench/worker/validate.sh"
