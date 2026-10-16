#!/usr/bin/env bash
# Tests for engram-resume-fallback.sh. Run: bash plugins/toolkit/hooks/tests/engram-resume-fallback.test.sh
set -u

HOOK="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/engram-resume-fallback.sh"
failures=0
TMP_ROOT=$(mktemp -d)
trap 'rm -rf "$TMP_ROOT"' EXIT

# fake_engram VERSION: put an `engram` stub printing VERSION first on PATH.
fake_engram() {
  local bin="$TMP_ROOT/bin-$1"
  mkdir -p "$bin"
  printf '#!/usr/bin/env bash\necho "engram %s"\n' "$1" >"$bin/engram"
  chmod +x "$bin/engram"
  printf '%s:%s\n' "$bin" "$PATH"
}

# run SOURCE PATH_VALUE: run the hook and keep stdout in $LAST_STDOUT.
LAST_STDOUT=""
LAST_EXIT=0
run() {
  LAST_STDOUT=$(jq -n --arg s "$1" '{hook_event_name: "SessionStart", source: $s}' |
    PATH=$2 bash "$HOOK" 2>/dev/null)
  LAST_EXIT=$?
}

# assert LABEL CONDITION...: run a test command and record PASS/FAIL.
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

is_empty() { [[ -z $LAST_STDOUT ]]; }
injects_fallback() {
  jq -e '.hookSpecificOutput.hookEventName == "SessionStart"
    and (.hookSpecificOutput.additionalContext | contains("engram save"))' \
    >/dev/null 2>&1 <<<"$LAST_STDOUT"
}

echo "== affected versions inject the CLI fallback =="

run resume "$(fake_engram 3.4.0)"
assert 'resume on 3.4.0 injects fallback' injects_fallback
assert 'resume on 3.4.0 exits 0' test "$LAST_EXIT" -eq 0

run resume "$(fake_engram 3.3.2)"
assert 'resume on older version injects fallback' injects_fallback

echo "== everything else stays silent =="

run resume "$(fake_engram 3.4.1)"
assert 'resume on fixed version is silent' is_empty

run resume "$(fake_engram 3.10.0)"
assert 'version compare is numeric, not lexical' is_empty

run startup "$(fake_engram 3.4.0)"
assert 'startup is silent' is_empty

empty_bin="$TMP_ROOT/empty-bin"
mkdir -p "$empty_bin"
run resume "$empty_bin:/usr/bin:/bin"
assert 'missing engram is silent' is_empty
assert 'missing engram exits 0' test "$LAST_EXIT" -eq 0

echo
if [[ $failures -gt 0 ]]; then
  echo "$failures case(s) failed"
  exit 1
fi
echo "All cases passed"
