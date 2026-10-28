#!/usr/bin/env bash
# Tests for the Antigravity adapter of prefer-modern-cli.sh.
# Run: bash plugins/toolkit/hooks/tests/agy-prefer-modern-cli.test.sh
# Payloads follow agy's PreToolUse contract (bundled agy-customizations docs).
set -u

ADAPTER="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/agy/prefer-modern-cli.sh"
failures=0

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

# command_payload COMMAND: a run_command payload as agy sends it.
command_payload() {
  jq -n --arg cmd "$1" '{toolCall: {name: "run_command", args: {CommandLine: $cmd}},
    stepIdx: 3, conversationId: "c1", workspacePaths: ["/tmp/ws"]}'
}

echo "== agy: legacy tools are denied =="
expect 'ls is denied with the Claude message' \
  '.decision == "deny" and (.reason | startswith("Use eza instead of ls."))' "$(command_payload 'ls -la')"
expect 'grep is denied with the Claude message' \
  '.decision == "deny" and (.reason | startswith("Use rg instead of grep."))' "$(command_payload 'git log | grep fix')"

# "ask" keeps agy's own permission flow; "allow" would skip the user's prompt.
echo "== agy: everything else keeps the normal permission flow =="
expect 'a modern tool is left to agy' '. == {decision: "ask"}' "$(command_payload 'rg foo')"
expect 'the legacy-cli marker is left to agy' '. == {decision: "ask"}' "$(command_payload 'ls # legacy-cli')"
expect 'another tool is left to agy' '. == {decision: "ask"}' \
  '{"toolCall": {"name": "view_file", "args": {"AbsolutePath": "/tmp/ws/ls"}}, "stepIdx": 1}'

# Unlike the Claude hook, the agy adapter fails closed.
echo "== agy: a malformed payload is denied =="
expect 'a payload that is not JSON is denied' '.decision == "deny"' 'not json {'
expect 'an empty payload is denied' '.decision == "deny"' ''
expect 'a run_command without CommandLine is denied' '.decision == "deny"' \
  '{"toolCall": {"name": "run_command", "args": {}}, "stepIdx": 2}'

echo
if [[ $failures -gt 0 ]]; then
  echo "$failures case(s) failed"
  exit 1
fi
echo "All cases passed"
