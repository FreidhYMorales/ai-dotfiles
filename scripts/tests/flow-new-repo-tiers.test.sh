#!/usr/bin/env bash
# Structural test for new repos set up by /flow:foundation and /flow:bootstrap:
# their skills and templates teach both targets (check-fast between turns,
# check as the full gate), the agent rule and the check-fast permission.
# Run: bash scripts/tests/flow-new-repo-tiers.test.sh
# shellcheck disable=SC2016 # literal markdown backticks
set -u

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
FLOW="$ROOT/plugins/flow/skills"
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

# file_has FILE TEXT: FILE contains TEXT literally.
file_has() { grep -qF -- "$2" "$1" 2>/dev/null; }

RULE='A story, a ship and CI are done when `make check` passes. Between turns the hook runs `check-fast`.'

CHECK="$FLOW/bootstrap/templates/check.md"
echo "== bootstrap check template: two targets and the agent rule =="
assert 'names both targets' \
  file_has "$CHECK" 'Every project exposes two targets: `make check`, the full quality gate, and `make check-fast`, its fast tier.'
assert 'carries the agent rule' file_has "$CHECK" "$RULE"
assert 'check-fast is static and has no tests' \
  file_has "$CHECK" '`check-fast` runs the static steps only (format check, lint), on the changed files when the tools allow it; no tests. It must finish in about 10 s.'
assert 'the skeleton defines check-fast' file_has "$CHECK" 'check-fast:'

AGENTS="$FLOW/foundation/templates/agents.md"
echo "== foundation AGENTS.md template: the agent rule =="
assert 'carries the agent rule' file_has "$AGENTS" "$RULE"
assert 'no longer says the hook runs make check' \
  test "$(grep -cF 'The toolkit Stop hook runs it before an agent may finish' "$AGENTS")" = 0

PERMS="$FLOW/foundation/templates/permissions.md"
echo "== foundation permissions template allows check-fast =="
assert 'the settings template allows make check-fast' file_has "$PERMS" '      "Bash(make check-fast:*)",'
assert 'the example allow list has make check-fast' \
  file_has "$PERMS" '"allow": ["Bash(make check:*)", "Bash(make check-fast:*)",'

ARCH="$FLOW/foundation/templates/architecture.md"
DEV="$FLOW/foundation/templates/development.md"
echo "== foundation architecture and development templates name both targets =="
assert 'architecture records the check-fast recipe' \
  file_has "$ARCH" '- Fast tier: `make check-fast`, steps 1-2 only (on the changed files when the tools allow it); the Stop hook runs it between turns.'
assert 'architecture keeps the agent rule' file_has "$ARCH" "$RULE"
assert 'development lists the fast tier command' file_has "$DEV" '| Fast checks (the hook runs them between turns) | `make check-fast` |'
assert 'development keeps the full gate command' file_has "$DEV" '| Full quality gate | `make check` |'

if ((failures)); then
  printf '%d case(s) failed\n' "$failures"
  exit 1
fi
echo 'All cases passed'
