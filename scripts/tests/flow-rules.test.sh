#!/usr/bin/env bash
# Structural test for the always-on rules: work is sized, delegated and verified
# by understanding, risk and resumability, never by file counts.
# Run: bash scripts/tests/flow-rules.test.sh
set -u

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
RULES="$ROOT/claude/CLAUDE.md"
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

# has FILE TEXT: FILE exists and contains TEXT literally.
has() { [[ -f $1 ]] && grep -qF -- "$2" "$1"; }

# lacks FILE TEXT: FILE exists and does not contain TEXT.
lacks() { [[ -f $1 ]] && ! grep -qF -- "$2" "$1"; }

echo "== rules: no file counts decide delegation =="
assert 'no inline-read file count' lacks "$RULES" '1–3 files'
assert 'no exploration file count' lacks "$RULES" '4+ files'
assert 'no writer file count' lacks "$RULES" '2+ non-trivial files'

echo "== rules: size by understanding, risk and resumability =="
assert 'size names one bounded read' has "$RULES" 'understood within one bounded read'
# shellcheck disable=SC2016
assert 'size names resumability' has "$RULES" 'resumable from the request plus `git diff`'

echo "== rules: risk comes from the single high-risk list =="
# Named by skill, not repo path: the rules load in every project.
# Backticks in the expected string are literal markdown.
# shellcheck disable=SC2016
assert 'rules point to the high-risk list' has "$RULES" '`references/high-risk.md` of the `flow:pair` skill'

if [[ $failures -gt 0 ]]; then
  echo "$failures case(s) failed"
  exit 1
fi
echo "All cases passed"
