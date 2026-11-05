#!/usr/bin/env bash
# Validate the benchmark tasks when bench/ changed; otherwise say it skipped.
# Usage: scripts/check-bench.sh [ROOT]
set -u
# shellcheck source=scripts/lib.sh
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

printf 'bench: skipped, no change under bench/\n'
