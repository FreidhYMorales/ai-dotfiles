#!/usr/bin/env bash
# Lint every tracked shell script with shellcheck (and shfmt -d when installed).
# Shell scripts are *.sh files plus extensionless files with a sh/bash shebang.
# Symlinks are skipped so a shared target is linted once. Vendored third-party
# trees (packs/vendor/) are pinned byte for byte and are not linted.
set -u
# shellcheck source=scripts/lib.sh
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

# changed_files: uncommitted work plus the branch's commits not on origin/main.
changed_files() {
  {
    git -C "$ROOT" diff --name-only HEAD
    git -C "$ROOT" diff --name-only origin/main...HEAD 2>/dev/null
    git -C "$ROOT" ls-files --others --exclude-standard
  } | sort -u
}

# sourced_files: every path named by a `# shellcheck source=` directive.
sourced_files() {
  rg --no-filename --only-matching --replace '$1' '^\s*# shellcheck source=(\S+)' "$ROOT" | sort -u
}

# candidates: every repo file, or with CHECK_SHELL_CHANGED=1 only the changed
# ones; a changed sourced lib can break any script, so it brings back every
# file, and so does a repo with no HEAD, where nothing can be diffed.
candidates() {
  local changed
  if [[ -n ${CHECK_SHELL_CHANGED:-} ]] && git -C "$ROOT" rev-parse --verify --quiet HEAD >/dev/null; then
    changed=$(changed_files)
    if ! rg --quiet --fixed-strings --line-regexp --file <(sourced_files) <<<"$changed"; then
      printf '%s\n' "$changed"
      return
    fi
  fi
  repo_files
}

scripts=()
while IFS= read -r f; do
  path="$ROOT/$f"
  [[ -f $path && ! -L $path && $f != packs/vendor/* ]] || continue
  if [[ $f == *.sh ]] || head -n1 "$path" | rg -q '^#!.*\b(ba)?sh\b'; then
    scripts+=("$f")
  fi
done < <(candidates)

if [[ ${#scripts[@]} -eq 0 ]]; then
  if [[ -n ${CHECK_SHELL_CHANGED:-} ]]; then ok "no changed shell scripts"; else ok "no shell scripts found"; fi
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
