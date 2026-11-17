#!/usr/bin/env bash
# Run every verification step, keep going on failure, then print a summary.
# Usage: scripts/check.sh [ROOT]
set -u
here=$(dirname "${BASH_SOURCE[0]}")
root=${1:-$here/..}
# The full gate lints every script; only the check-fast recipe sets this mode.
unset CHECK_SHELL_CHANGED

steps=(shell:check-shell.sh json:check-json.sh structure:check-structure.sh
  settings:check-settings.sh skills:check-skills.sh workflows:check-workflows.sh tests:run-tests.sh bench:check-bench.sh)
failed=()
for step in "${steps[@]}"; do
  name=${step%%:*}
  printf '\n== %s ==\n' "$name"
  bash "$here/${step#*:}" "$root" || failed+=("$name")
done

printf '\n== summary ==\n'
if [[ ${#failed[@]} -gt 0 ]]; then
  for name in "${failed[@]}"; do printf 'FAILED: %s\n' "$name"; done
  printf '%d of %d step(s) failed\n' "${#failed[@]}" "${#steps[@]}"
  exit 1
fi
printf 'All checks passed (%d steps)\n' "${#steps[@]}"
