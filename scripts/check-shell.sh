#!/usr/bin/env bash
# Lint every tracked shell script with shellcheck (and shfmt -d when installed).
# Shell scripts are *.sh files plus extensionless files with a sh/bash shebang.
# Symlinks are skipped so a shared target is linted once. Vendored third-party
# trees (packs/vendor/) are pinned byte for byte and are not linted.
set -u
# shellcheck source=scripts/lib.sh
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

scripts=()
while IFS= read -r f; do
  path="$ROOT/$f"
  [[ -f $path && ! -L $path && $f != packs/vendor/* ]] || continue
  if [[ $f == *.sh ]] || head -n1 "$path" | rg -q '^#!.*\b(ba)?sh\b'; then
    scripts+=("$f")
  fi
done < <(repo_files)

if [[ ${#scripts[@]} -eq 0 ]]; then
  ok "no shell scripts found"
  finish shell
fi

cd "$ROOT" || exit 1
# Lint the scripts in parallel, one process each; results print in file order.
declare -A failed=()
while IFS= read -r -d '' f; do failed[$f]=1; done < <(
  # shellcheck disable=SC2016 # $1 is expanded by the per-script bash, not here.
  printf '%s\0' "${scripts[@]}" |
    xargs -0 -P "$(nproc)" -I{} bash -c 'shellcheck -x "$1" >&2 || printf "%s\0" "$1"' _ {}
)
for f in "${scripts[@]}"; do
  if [[ -n ${failed[$f]:-} ]]; then err "shellcheck $f"; else ok "shellcheck $f"; fi
done

if command -v shfmt >/dev/null 2>&1; then
  if shfmt -d -i 2 -ci "${scripts[@]}" >&2; then ok "shfmt"; else err "shfmt: formatting differs"; fi
else
  printf 'skip  shfmt not installed; formatting not checked\n'
fi
finish shell
