#!/usr/bin/env bash
# Lint GitHub Actions workflows with actionlint (which also runs shellcheck on
# `run:` scripts). Skipped when actionlint is not installed; CI pins it.
set -u
# shellcheck source=scripts/lib.sh
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

ACTIONLINT=${ACTIONLINT:-actionlint}

workflows=()
while IFS= read -r f; do
  [[ $f == .github/workflows/*.yml || $f == .github/workflows/*.yaml ]] || continue
  [[ -f $ROOT/$f ]] && workflows+=("$f")
done < <(repo_files)

if [[ ${#workflows[@]} -eq 0 ]]; then
  ok "no workflows found"
  finish workflows
fi

if ! command -v "$ACTIONLINT" >/dev/null 2>&1; then
  printf 'skip  actionlint not installed; workflows not checked\n'
  finish workflows
fi

cd "$ROOT" || exit 1
for f in "${workflows[@]}"; do
  if "$ACTIONLINT" "$f" >&2; then ok "actionlint $f"; else err "actionlint $f"; fi
done
finish workflows
