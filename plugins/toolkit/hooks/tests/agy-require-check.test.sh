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

# repo NAME STATUS: a trusted repo with uncommitted changes whose `make check` exits STATUS.
repo() {
  local dir="$TMP_ROOT/$1"
  mkdir -p "$dir"
  git -C "$dir" init -q
  git -C "$dir" config require-check.trusted true
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
expect 'a failing check at executionNum 0 continues with the failure tail' \
  '.decision == "continue" and (.reason | startswith("make check failed")) and (.reason | contains("lint: broken thing"))' \
  "$(stop_payload "$red" NO_TOOL_CALL 0)"

echo "== agy: a failing check-fast keeps the turn going =="
fast="$TMP_ROOT/fast"
mkdir -p "$fast"
git -C "$fast" init -q
git -C "$fast" config require-check.trusted true
printf 'check:\n\ttrue\ncheck-fast:\n\t@echo "lint: fast thing"; exit 1\n' >"$fast/Makefile"
expect 'a failing check-fast continues with its own failure tail' \
  '.decision == "continue" and (.reason | startswith("make check-fast failed")) and (.reason | contains("lint: fast thing"))' \
  "$(stop_payload "$fast" NO_TOOL_CALL 0)"

echo "== agy: a passing make check lets agy stop =="
green=$(repo green 0)
expect 'a passing check lets agy stop' '. == {decision: "stop"}' "$(stop_payload "$green" NO_TOOL_CALL 0)"

# A later execution means agy is already continuing because of this gate.
echo "== agy: the gate never traps a session =="
expect 'a failing check at executionNum 1 lets agy stop' '. == {decision: "stop"}' \
  "$(stop_payload "$red" NO_TOOL_CALL 1)"
expect 'a failing check on a later execution lets agy stop' '. == {decision: "stop"}' \
  "$(stop_payload "$red" NO_TOOL_CALL 2)"
expect 'a cancel lets agy stop on a failing check' '. == {decision: "stop"}' \
  "$(stop_payload "$red" USER_CANCELED 0)"
expect 'hitting the invocation limit lets agy stop on a failing check' '. == {decision: "stop"}' \
  "$(stop_payload "$red" MAX_INVOCATIONS 0)"

# A Stop adapter never answers continue on input it cannot read.
echo "== agy: an unreadable payload lets agy stop =="
expect 'an empty payload lets agy stop' '. == {decision: "stop"}' ''
expect 'a payload that is not JSON lets agy stop' '. == {decision: "stop"}' 'not json {'
# Run from inside the failing repo: a missing workspace must not fall back to it.
out=$(cd "$red" && jq -n '{executionNum: 0, terminationReason: "NO_TOOL_CALL"}' | bash "$ADAPTER" 2>/dev/null)
if jq -e '. == {decision: "stop"}' >/dev/null 2>&1 <<<"$out"; then
  printf 'PASS  %s\n' 'a payload without workspacePaths lets agy stop, even inside a failing repo'
else
  printf 'FAIL  %s (got: %s)\n' 'a payload without workspacePaths lets agy stop, even inside a failing repo' "$out"
  failures=$((failures + 1))
fi

# Without a numeric executionNum the adapter cannot tell a re-entry apart, so
# it must not risk continuing forever.
for n in null -1 '"1"'; do
  expect "executionNum $n lets agy stop on a failing check" '. == {decision: "stop"}' \
    "$(stop_payload "$red" NO_TOOL_CALL 0 | jq -c --argjson n "$n" '.executionNum = $n')"
done
expect 'a missing executionNum lets agy stop on a failing check' '. == {decision: "stop"}' \
  "$(stop_payload "$red" NO_TOOL_CALL 0 | jq -c 'del(.executionNum)')"

# Run from inside the failing repo: an empty or relative workspace must not
# resolve against the hook's own cwd.
for ws in '' '.' 'red'; do
  label="workspace path '$ws' lets agy stop, even inside a failing repo"
  out=$(cd "$red" && stop_payload "$ws" NO_TOOL_CALL 0 | bash "$ADAPTER" 2>/dev/null)
  if jq -e '. == {decision: "stop"}' >/dev/null 2>&1 <<<"$out"; then
    printf 'PASS  %s\n' "$label"
  else
    printf 'FAIL  %s (got: %s)\n' "$label" "$out"
    failures=$((failures + 1))
  fi
done

echo "== agy: a /flow:pair red step goes through =="
pair=$(repo pair 1)
git -C "$pair" add -A
git -C "$pair" -c user.name=t -c user.email=t@t -c core.hooksPath=/dev/null commit -qm 'test: red'
printf 'wip\n' >"$pair/wip.txt"
# Same failing repo without the marker: the gate holds, so the marker is what lets go.
expect 'without the marker the red repo continues' '.decision == "continue"' "$(stop_payload "$pair" NO_TOOL_CALL 0)"
marker=$(cd "$pair" && git rev-parse --path-format=absolute --git-path flow-pair-red)
printf '%s\n%s\n' "$(git -C "$pair" branch --show-current)" "$(git -C "$pair" rev-parse HEAD)" >"$marker"
expect 'a red marker on the branch lets agy stop' '. == {decision: "stop"}' "$(stop_payload "$pair" NO_TOOL_CALL 0)"

echo
if [[ $failures -gt 0 ]]; then
  echo "$failures case(s) failed"
  exit 1
fi
echo "All cases passed"
