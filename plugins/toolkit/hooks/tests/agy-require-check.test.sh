#!/usr/bin/env bash
# Tests for the Antigravity adapter of require-check.sh.
# Run: bash plugins/toolkit/hooks/tests/agy-require-check.test.sh
# Payloads follow agy's Stop contract (bundled agy-customizations docs).
set -u

ADAPTER="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/agy/require-check.sh"
failures=0
TMP_ROOT=$(mktemp -d)
trap 'rm -rf "$TMP_ROOT"' EXIT

# Isolate fixture repos from the user's global git config and hooks.
export GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1
unset SKIP_REQUIRE_CHECK AI_HOOKS_OFF
# Isolate the green-state cache from the real ~/.cache.
export XDG_CACHE_HOME="$TMP_ROOT/cache"

# repo NAME STATUS: a repo with uncommitted changes whose `make check` exits STATUS.
repo() {
  local dir="$TMP_ROOT/$1"
  mkdir -p "$dir"
  git -C "$dir" init -q
  printf 'check:\n\t@echo "lint: broken thing"; exit %s\n' "$2" >"$dir/Makefile"
  printf '%s\n' "$dir"
}

# stop_payload DIR REASON EXECUTION: a Stop payload as agy sends it.
stop_payload() {
  jq -n --arg dir "$1" --arg reason "$2" --argjson n "$3" '{executionNum: $n, terminationReason: $reason,
    error: "", fullyIdle: true, conversationId: "c1", workspacePaths: [$dir]}'
}

# expect LABEL FILTER STDIN: the adapter's stdout satisfies the jq FILTER.
expect() {
  local label=$1 filter=$2 input=$3 out
  out=$(printf '%s' "$input" | bash "$ADAPTER" 2>/dev/null)
  if jq -e "$filter" >/dev/null 2>&1 <<<"$out"; then
    printf 'PASS  %s\n' "$label"
  else
    printf 'FAIL  %s (got: %s)\n' "$label" "$out"
    failures=$((failures + 1))
  fi
}

echo "== agy: a failing make check keeps the turn going =="
red=$(repo red 1)
expect 'a failing check continues with the failure tail' \
  '.decision == "continue" and (.reason | startswith("make check failed")) and (.reason | contains("lint: broken thing"))' \
  "$(stop_payload "$red" NO_TOOL_CALL 1)"

echo
if [[ $failures -gt 0 ]]; then
  echo "$failures case(s) failed"
  exit 1
fi
echo "All cases passed"
