#!/usr/bin/env bash
# Tests for plugins/look/tests/look.test.sh (the claude plugin test wrapper),
# with stub `claude` binaries. Run: bash scripts/tests/look-wrapper.test.sh
set -u

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
WRAPPER="$ROOT/plugins/look/tests/look.test.sh"
PIN=$(<"$ROOT/plugins/look/tests/claude-code.version")
failures=0
TMP_ROOT=$(mktemp -d)
trap 'rm -rf "$TMP_ROOT"' EXIT

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

# stub VERSION: a fake claude that logs its calls and its HOME to $TMP_ROOT/calls.
stub() {
  local dir=$TMP_ROOT/stub
  rm -rf "$dir" "$TMP_ROOT/calls"
  mkdir -p "$dir"
  printf '#!%s\n' "$(command -v bash)" >"$dir/claude"
  cat >>"$dir/claude" <<EOS
if [[ \$1 == --version ]]; then echo "$1 (Claude Code)"; exit 0; fi
echo "\$* HOME=\$HOME" >>"$TMP_ROOT/calls"
exit \${STUB_RC:-0}
EOS
  chmod +x "$dir/claude"
  for tool in mktemp rm; do ln -sf "$(command -v "$tool")" "$dir/$tool"; done
}

# run [ENV...]: run the wrapper with only the stub dir on PATH.
run() {
  OUT=$(env PATH="$TMP_ROOT/stub" "$@" "$(command -v bash)" "$WRAPPER" 2>&1)
  RC=$?
}
not() { ! "$@"; }
out_has() { [[ $OUT == *"$1"* ]]; }
calls_has() { [[ -f $TMP_ROOT/calls && $(<"$TMP_ROOT/calls") == *"$1"* ]]; }

echo "== claude missing =="
mkdir -p "$TMP_ROOT/stub"
for tool in mktemp rm; do ln -sf "$(command -v "$tool")" "$TMP_ROOT/stub/$tool"; done
run LOOK_REQUIRE_CLAUDE=0
assert 'skips successfully' test "$RC" -eq 0
assert 'says SKIP' out_has 'SKIP'
run LOOK_REQUIRE_CLAUDE=1
assert 'fails when claude is required' test "$RC" -ne 0

echo "== claude present =="
stub "$PIN"
run
assert 'passes on the pinned version' test "$RC" -eq 0
assert 'prints the version' out_has "$PIN"
assert 'does not warn on the pin' not out_has WARN
assert 'validates the plugin' calls_has 'plugin validate'
assert 'tests the plugin' calls_has 'plugin test'
assert 'runs with a temporary HOME' not calls_has "HOME=$HOME"

stub 9.9.9
run
assert 'warns on a version mismatch' out_has 'WARN'
assert 'still runs the tests on a mismatch' calls_has 'plugin test'

stub "$PIN"
run STUB_RC=1
assert 'fails when claude plugin test fails' test "$RC" -ne 0

echo
if [[ $failures -gt 0 ]]; then
  echo "$failures case(s) failed"
  exit 1
fi
echo "All cases passed"
