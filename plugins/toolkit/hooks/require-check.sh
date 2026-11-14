#!/usr/bin/env bash
# Stop hook: refuse to finish while the project's fast tier fails. It runs
# `make check-fast` when the root Makefile defines it (static checks, 60 s
# limit) and `make check` otherwise (300 s); `make check` stays the gate for a
# story, a ship and CI. Runs from the git root of the cwd when the repo has
# uncommitted changes, and only in a repo opted in
# with `git config require-check.trusted true`. Exit 2 feeds the failure tail
# back to Claude; a second stop in the same turn reports it instead. A tree identical to the last green run is skipped (cache in
# ~/.cache/require-check). Opt out with SKIP_REQUIRE_CHECK=1. A branch-bound
# /flow:pair red marker turns the block into a systemMessage (see below).
set -u
# shellcheck source=plugins/toolkit/hooks/lib.sh
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh" && hook_off

[[ ${SKIP_REQUIRE_CHECK:-} == 1 ]] && exit 0

input=$(cat)
if [[ -n $input ]] && jq -e . >/dev/null 2>&1 <<<"$input"; then
  active=$(jq -r '.stop_hook_active // false' <<<"$input")
  dir=$(jq -r '.cwd // empty' <<<"$input")
fi
dir=${dir:-$PWD}

[[ -d $dir ]] || exit 0
# Always check from the repo root, so stopping in a subdirectory is no escape.
# Refuse git dirs found by discovery that are not a `.git` (a clone can ship
# a directory that looks like a git dir and carries its own config and trust).
dir=$(git -c safe.bareRepository=explicit -C "$dir" rev-parse --show-toplevel 2>/dev/null) || exit 0
[[ -n $(git -C "$dir" status --porcelain 2>/dev/null) ]] || exit 0

makefile=""
for name in GNUmakefile makefile Makefile; do
  if [[ -f $dir/$name ]]; then
    makefile=$name
    break
  fi
done
[[ -n $makefile ]] || exit 0

# Trust: never run (or even parse) a Makefile the owner has not opted in to.
# Only the repo's local config counts: a clone never carries it, and a global
# value would trust every repo at once.
if [[ $(git -C "$dir" config --local --get require-check.trusted 2>/dev/null) != true ]]; then
  jq -n --arg m "require-check: $dir is not trusted, so neither make check nor make check-fast was run. Opt in from that repo with: git config require-check.trusted true" \
    '{systemMessage: $m}'
  exit 0
fi

# Detect `check` and `check-fast` from make's database without running any
# recipe: the goal `.DEFAULT` has no recipe, and -q never executes commands.
# `check-fast` counts only with a recipe or prerequisites of its own, so one
# listed only in .PHONY never hides a red `check`.
targets=$(make -C "$dir" -f "$makefile" -npq .DEFAULT 2>/dev/null |
  awk '/^# Not a target:/ { skip = 1; next }
       /^check:/ && !skip { check = 1 }
       /^check-fast:/ && !skip { entry = 1; if ($0 !~ /^check-fast:[[:space:]]*$/) fast = 1 }
       entry && /^#  recipe to execute/ { fast = 1 }
       /^$/ { entry = 0 }
       { skip = 0 }
       END { print (check ? "check" : "") " " (fast ? "check-fast" : "") }')
if [[ $targets == *check-fast ]]; then
  target=check-fast
elif [[ $targets == check* ]]; then
  target=check
else
  exit 0
fi

# /flow:pair commits a failing test on purpose before the code that makes it
# pass. While that red test is committed it writes a marker (branch name, then
# the red test commit sha) at `git rev-parse --git-path flow-pair-red`, which
# resolves per worktree. Honour it only for the same branch while that commit
# is HEAD itself, so a marker forgotten after the green commit never disables
# the gate.
marker=$(cd "$dir" && git rev-parse --path-format=absolute --git-path flow-pair-red 2>/dev/null)
if [[ -n $marker && -f $marker ]]; then
  { IFS= read -r red_branch && IFS= read -r red_sha; } <"$marker"
  branch=$(git -C "$dir" symbolic-ref --quiet --short HEAD 2>/dev/null)
  if [[ -n ${red_branch:-} && -n ${red_sha:-} && $branch == "$red_branch" ]] &&
    [[ $(git -C "$dir" rev-parse --verify --quiet HEAD 2>/dev/null) == "$red_sha" ]]; then
    jq -n --arg m "require-check: a red test is committed on purpose by /flow:pair on $branch ($red_sha); make $target is expected to fail until it is green." \
      '{systemMessage: $m}'
    exit 0
  fi
fi

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

limit=300
[[ $target == check-fast ]] && limit=60
output=$(cd "$dir" && timeout "$limit" make -f "$makefile" "$target" 2>&1)
status=$?
if [[ $status -eq 0 ]]; then
  mkdir -p "${cache_file%/*}" && printf '%s\n' "$state" >"$cache_file.tmp" && mv -f "$cache_file.tmp" "$cache_file"
  exit 0
fi

# Already blocked once this turn: never block again (that would loop), but
# say the check is still red instead of letting the stop pass silently.
if [[ ${active:-false} == true ]]; then
  jq -n --arg m "require-check: make $target is still red, stopping anyway:
$(tail -n 60 <<<"$output")" '{systemMessage: $m}'
  exit 0
fi

{
  if [[ $status -eq 124 ]]; then
    echo "make $target timed out after ${limit}s — fix these before finishing:"
  else
    echo "make $target failed — fix these before finishing:"
  fi
  tail -n 60 <<<"$output"
} >&2
exit 2
