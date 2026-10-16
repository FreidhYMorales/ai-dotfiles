#!/usr/bin/env bash
# Validate that every tracked *.json file parses with jq.
set -u
# shellcheck source=scripts/lib.sh
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

while IFS= read -r f; do
  [[ $f == *.json && -f $ROOT/$f ]] || continue
  if jq -e . "$ROOT/$f" >/dev/null 2>&1; then ok "$f"; else err "invalid JSON: $f"; fi
done < <(repo_files)
finish json
