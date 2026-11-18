#!/usr/bin/env bash
# Structural test for the retired Antigravity (agy) support: the open items
# and the tracked files outside history no longer name it.
# Run: bash scripts/tests/no-agy.test.sh
set -u

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
IDEAS="$ROOT/docs/ideas.md"
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

# idea N: the ideas log section of idea N, up to the next level-2 heading.
idea() { awk -v h="## $1. " 'index($0, h) == 1 { on = 1; print; next } /^## / { on = 0 } on' "$IDEAS"; }

echo "== open items name no agy =="
idea29=$(idea 29)
assert 'idea 29 is found' test -n "$idea29"
assert 'idea 29 is done' rg -qxF -- '- Done: retire-antigravity stories 01-04 (2026-11-18).' <<<"$idea29"
idea20=$(idea 20)
assert 'idea 20 is found' test -n "$idea20"
assert 'idea 20 still names the plugins and the marketplace' rg -q 'plugins.*marketplace' <<<"$idea20"
assert 'idea 20 names no agy' test -z "$(rg -i 'agy' <<<"$idea20")"
assert 'multi-agent-port #47 is dropped' rg -q '^47\. \[-\] dropped: superseded by retire-antigravity' \
  "$ROOT/docs/plans/multi-agent-port/backlog.md"

echo "== only history and the retirement tests name agy =="
# Tracked files only, so this machine and CI scan the same set.
files=$(git -C "$ROOT" -c core.quotepath=off ls-files)
pattern='agy|antigravity|\.gemini'
# scan: the hits in the listed files (one path per line on stdin).
scan() { (cd "$ROOT" && tr '\n' '\0' | xargs -0 rg -n -i -H --no-heading "$@" -- "$pattern") || true; }
# Guard against a scan that finds nothing at all: the ideas log must show up.
assert 'the scan sees the ideas log' rg -qx 'docs/ideas.md' <<<"$(scan -l <<<"$files")"
history='^(docs/plans/|docs/ideas\.md$|packs/vendor/|scripts/tests/no-agy\.test\.sh$)'
hits=$(rg -v "$history" <<<"$files" | scan)
# The regression tests of retire-antigravity stories 01-03, by file and a
# stable fragment of each line.
allowed_lines='^(scripts/tests/install-targets\.test\.sh:[0-9]+:'
allowed_lines+='|scripts/tests/ai-update\.test\.sh:[0-9]+:.*(regen-agy|\.gemini/antigravity-cli|an Antigravity dir)'
allowed_lines+='|scripts/tests/gen-agents\.test\.sh:[0-9]+:.*(no antigravity/ directory|names only OpenCode files)'
# sd{2}: the other retirement scan rejects that plain word in any file.
allowed_lines+='|scripts/tests/no-sd{2}\.test\.sh:[0-9]+:.*(retire-antigravity/03|hooks/agy)'
allowed_lines+='|scripts/tests/port-docs\.test\.sh:[0-9]+:.*names no agy, antigravity or \.gemini)'
stray=$(rg -v "$allowed_lines" <<<"$hits")
assert 'no file outside history names agy' test -z "$stray"
[[ -n $stray ]] && printf '%s\n' "$stray"

if [[ $failures -gt 0 ]]; then
  echo "$failures case(s) failed"
  exit 1
fi
echo "All cases passed"
