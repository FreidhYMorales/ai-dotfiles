#!/usr/bin/env bash
# Stop hook: refuse to finish while the project's `make check` fails.
# Runs from the git root of the cwd when the repo has uncommitted changes and a
# root Makefile that defines a `check` target. Exit 2 feeds the failure tail
# back to Claude. A tree identical to the last green run is skipped (cache in
# ~/.cache/require-check). Opt out with SKIP_REQUIRE_CHECK=1.
set -u

[[ ${SKIP_REQUIRE_CHECK:-} == 1 ]] && exit 0

input=$(cat)
if [[ -n $input ]] && jq -e . >/dev/null 2>&1 <<<"$input"; then
  [[ $(jq -r '.stop_hook_active // false' <<<"$input") == true ]] && exit 0
  dir=$(jq -r '.cwd // empty' <<<"$input")
fi
dir=${dir:-$PWD}

[[ -d $dir ]] || exit 0
# Always check from the repo root, so stopping in a subdirectory is no escape.
dir=$(git -C "$dir" rev-parse --show-toplevel 2>/dev/null) || exit 0
[[ -n $(git -C "$dir" status --porcelain 2>/dev/null) ]] || exit 0

makefile=""
for name in GNUmakefile makefile Makefile; do
  if [[ -f $dir/$name ]]; then
    makefile=$name
    break
  fi
done
[[ -n $makefile ]] || exit 0

# Detect a `check` target from make's database without running any recipe:
# the goal `.DEFAULT` has no recipe, and -q never executes commands.
has_check=$(make -C "$dir" -f "$makefile" -npq .DEFAULT 2>/dev/null |
  awk '/^# Not a target:/ { skip = 1; next }
       /^check:/ && !skip { found = 1 }
       { skip = 0 }
       END { print found ? "yes" : "no" }')
[[ $has_check == yes ]] || exit 0

# Skip when the tree is exactly the one that last passed: HEAD, every staged
# and unstaged change, and the content of untracked files. Any edit reruns it;
# failures are never cached.
cache_file=${XDG_CACHE_HOME:-$HOME/.cache}/require-check/$(printf '%s' "$dir" | sha256sum | cut -c1-16)
state=$({
  git -C "$dir" rev-parse HEAD 2>/dev/null
  # Staged vs HEAD (or the empty tree before the first commit), then unstaged.
  git -C "$dir" diff --cached --binary 2>/dev/null
  git -C "$dir" diff --binary 2>/dev/null
  (cd "$dir" && git ls-files -o --exclude-standard -z | xargs -0 -r sha256sum 2>/dev/null)
} | sha256sum | cut -d' ' -f1)
[[ -f $cache_file && $(<"$cache_file") == "$state" ]] && exit 0

output=$(cd "$dir" && timeout 300 make -f "$makefile" check 2>&1)
status=$?
if [[ $status -eq 0 ]]; then
  mkdir -p "${cache_file%/*}" && printf '%s\n' "$state" >"$cache_file.tmp" && mv -f "$cache_file.tmp" "$cache_file"
  exit 0
fi

{
  if [[ $status -eq 124 ]]; then
    echo "make check timed out after 300s — fix these before finishing:"
  else
    echo "make check failed — fix these before finishing:"
  fi
  tail -n 60 <<<"$output"
} >&2
exit 2
