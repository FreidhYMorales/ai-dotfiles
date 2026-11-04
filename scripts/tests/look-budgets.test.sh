#!/usr/bin/env bash
# The look cases that advance the clock over several polls declare a 30 s
# budget, so a slow CI runner never trips the harness's 5 s watchdog
# (story 18). Run: bash scripts/tests/look-budgets.test.sh
set -u

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
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

# declares FILE NAME: the look case NAME in FILE opens with the 30 s budget.
declares() {
  rg -qF "test('$2', { timeoutMs: 30_000 }, async" "$ROOT/plugins/look/tests/$1"
}

assert 'agent.list two-polls case has the 30 s budget' declares agent.test.tsx \
  'an agent missing from agent.list on two polls in a row is stopped, with no alert'

# missing_budget DIR: the harness cases (their callback takes `$`) in DIR's
# *.test.tsx that lack the budget, one FILE:LINE:DECLARATION per line.
missing_budget() {
  rg -n --no-heading --glob '*.test.tsx' '^\s*test\(.*\(\$' "$1" | rg -vF 'timeoutMs: 30_000' | sort -t: -k2n
}

# none_missing DIR: DIR has no harness case without the budget; names any it finds.
none_missing() {
  local missing
  missing=$(missing_budget "$1")
  [[ -z $missing ]] && return 0
  printf '%s\n' "$missing"
  return 1
}

fixture=$(mktemp -d)
trap 'rm -rf "$fixture"' EXIT
cat >"$fixture/a.test.tsx" <<'EOF'
test('no budget', async ($, on) => {})
test('has budget', { timeoutMs: 30_000 }, async ($, on) => {})
for (const s of ['a']) {
  test(`looped ${s}`, async ($, on) => {})
}
test('no harness async', async () => {})
test('no harness sync', () => {})
EOF
expected="$fixture/a.test.tsx:1:test('no budget', async (\$, on) => {})
$fixture/a.test.tsx:4:  test(\`looped \${s}\`, async (\$, on) => {})"

same() { [[ $1 == "$2" ]]; }
assert 'the check names only the harness cases without the budget' same "$(missing_budget "$fixture")" "$expected"
assert 'every look harness case has the 30 s budget' none_missing "$ROOT/plugins/look/tests"

echo
if [[ $failures -gt 0 ]]; then
  echo "$failures case(s) failed"
  exit 1
fi
echo "All cases passed"
