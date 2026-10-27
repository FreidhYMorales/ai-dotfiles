#!/usr/bin/env bash
# Structural test for how flow planning ends in the loop: handoff, next and the
# plan lookup order. Asserts only the contract strings live projects rely on.
# Run: bash scripts/tests/flow-handoff.test.sh
set -u

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SKILLS="$ROOT/plugins/flow/skills"
HANDOFF="$SKILLS/handoff/SKILL.md"
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

echo "== handoff: solo plans end in the backlog =="
assert 'handoff never recommends an /sdd command' lacks "$HANDOFF" '/sdd:'
# Backticks in the expected strings are literal markdown.
# shellcheck disable=SC2016
assert 'solo handoff goes through /flow:backlog' has "$HANDOFF" 'Solo plan: run `/flow:backlog`'
assert 'solo handoff names /flow:story 01 next' has "$HANDOFF" '/flow:story 01'

echo "== handoff: collaborative plans keep tasks.md =="
# shellcheck disable=SC2016
assert 'collaborative handoff writes tasks.md' has "$HANDOFF" 'Collaborative plan: write `<plan-dir>/tasks.md`'
# shellcheck disable=SC2016
assert 'collaborative handoff points to /flow:split' has "$HANDOFF" '| Collaborative plan | `tasks.md` in the plan dir, for `/flow:split` |'
assert 'handoff no longer mentions SDD at all' lacks "$HANDOFF" 'SDD'

NEXT="$SKILLS/next/SKILL.md"
echo "== next: tasks.md first, else the backlog =="
# shellcheck disable=SC2016
assert 'next reads tasks.md when it exists' has "$NEXT" 'If `<plan-dir>/tasks.md` exists, use it'
# shellcheck disable=SC2016
assert 'next falls back to the backlog' has "$NEXT" 'else read `<plan-dir>/backlog.md`'
# shellcheck disable=SC2016
assert 'backlog story is ready when every Requires is done' has "$NEXT" 'every `Requires: #N` is `[x]`'

echo
if [[ $failures -gt 0 ]]; then
  echo "$failures case(s) failed"
  exit 1
fi
echo "All cases passed"
