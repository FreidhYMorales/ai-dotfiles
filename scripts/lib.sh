#!/usr/bin/env bash
# Shared helpers for scripts/check-*.sh. Source it; do not execute it.
# Every check takes an optional ROOT argument (default: this repo) and exits
# non-zero when any error was reported.

# shellcheck disable=SC2034 # ROOT and errors are used by the sourcing script.
ROOT=$(cd "${1:-$(dirname "${BASH_SOURCE[0]}")/..}" && pwd)
errors=0

err() {
  printf 'ERROR %s\n' "$*" >&2
  errors=$((errors + 1))
}
warn() { printf 'WARN  %s\n' "$*" >&2; }
ok() { printf 'ok    %s\n' "$*"; }

# repo_files: tracked plus untracked-but-not-ignored files, relative to ROOT.
repo_files() { git -C "$ROOT" ls-files --cached --others --exclude-standard | sort -u; }

# finish NAME: print the step result and exit with its status.
finish() {
  if [[ $errors -gt 0 ]]; then
    printf '%s: %d error(s)\n' "$1" "$errors" >&2
    exit 1
  fi
  printf '%s: ok\n' "$1"
  exit 0
}
