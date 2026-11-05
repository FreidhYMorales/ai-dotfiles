#!/usr/bin/env bash
# Structural test: the lists the repo keeps by hand match what is on disk.
# Run: bash scripts/tests/repo-lists.test.sh
set -u

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
TOOLKIT="$ROOT/plugins/toolkit"
failures=0

assert() {
  local label=$1
  shift
  if "$@"; then
    printf 'PASS  %s\n' "$label"
  else
    printf 'FAIL  %s\n' "$label"
    failures=$((failures + 1))
  fi
}

# has TEXT FIXED: TEXT contains the fixed string.
has() { rg -qF -- "$2" <<<"$1"; }
lacks() { ! has "$@"; }

# Every hook script; lib.sh is a helper sourced by the hooks, not a hook.
hooks=()
for f in "$TOOLKIT"/hooks/*.sh; do
  name=${f##*/}
  name=${name%.sh}
  [[ $name == lib ]] || hooks+=("$name")
done

skills=()
for d in "$TOOLKIT"/skills/*/; do
  d=${d%/}
  skills+=("${d##*/}")
done

echo "== the README's toolkit row names every skill and hook =="
row=$(rg -F '| `plugins/toolkit/` |' "$ROOT/README.md")
assert 'the toolkit row is found' test -n "$row"
assert 'the scan found the 11 skills' test "${#skills[@]}" -ge 11
assert 'the scan found the 9 hooks' test "${#hooks[@]}" -ge 9
for name in "${skills[@]}"; do
  assert "the toolkit row names the skill $name" has "$row" "\`$name\`"
done
for name in "${hooks[@]}"; do
  assert "the toolkit row names the hook $name" has "$row" "\`$name\`"
done

echo "== make mutate covers every hook with its own test file =="
tested=()
for name in "${hooks[@]}"; do
  [[ -f $TOOLKIT/hooks/tests/$name.test.sh ]] && tested+=("$name")
done
# HOOKS is overridable, so an exported value must not decide this result.
plan=$(env -u HOOKS make --no-print-directory -C "$ROOT" -n mutate)
assert 'the scan found the 9 tested hooks' test "${#tested[@]}" -ge 9
for name in "${tested[@]}"; do
  assert "make mutate covers $name" has "$plan" "$name"
done

echo "== the repo's own .gitignore keeps local Claude settings out =="
clone=$(mktemp -d)
trap 'rm -rf "$clone"' EXIT
# No personal ignore file: only what the repo itself ships can ignore a path.
# An empty global config is not enough: git still reads ~/.config/git/ignore by
# default, so core.excludesFile has to point away from it.
git_clean() { GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_SYSTEM=/dev/null git -c core.excludesFile=/dev/null "$@"; }
# A new repo holding only the .gitignore: a clone of $ROOT would need the
# safe.directory setting CI keeps in the global config emptied here.
git_clean init -q "$clone/repo"
cp "$ROOT/.gitignore" "$clone/repo/.gitignore"
mkdir -p "$clone/repo/.claude"
: >"$clone/repo/.claude/settings.local.json"
: >"$clone/repo/.claude/other.json"
status=$(git_clean -C "$clone/repo" status --porcelain --untracked-files=all)
assert 'git status lists another new file under .claude' has "$status" '.claude/other.json'
assert 'git status does not list .claude/settings.local.json' lacks "$status" 'settings.local.json'

if ((failures > 0)); then
  printf '%d case(s) failed\n' "$failures"
  exit 1
fi
echo 'All cases passed'
