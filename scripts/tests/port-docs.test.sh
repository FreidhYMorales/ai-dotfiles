#!/usr/bin/env bash
# Structural test for the multi-agent port docs: the README, the install.sh
# header and docs/multi-agent.md describe how each agent is set up.
# Run: bash scripts/tests/port-docs.test.sh
set -u

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
README="$ROOT/README.md"
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

echo "== README names the rules paths each agent reads =="
# The layout row of the repo-root AGENTS.md.
row=$(rg -F '| `AGENTS.md` |' "$README")
assert 'the AGENTS.md row is found' test -n "$row"
assert 'README names the OpenCode rules path' has "$row" '~/.config/opencode/AGENTS.md'
assert 'README names the agy rules path' has "$row" '~/.gemini/config/AGENTS.md'
assert 'README drops the path agy does not read' lacks "$row" '~/.gemini/antigravity-cli/AGENTS.md'

if [[ $failures -gt 0 ]]; then
  echo "$failures case(s) failed"
  exit 1
fi
echo "All cases passed"
