#!/usr/bin/env bash
# Antigravity Stop adapter for require-check.sh: turns agy's payload into the
# Claude hook's input and its block into agy's continue. Anything else lets
# agy stop.

input=$(cat)
stop() {
  echo '{"decision": "stop"}'
  exit 0
}

# Only a normal turn end is gated: a cancel or a limit must never be held.
[[ $(jq -r '.terminationReason' <<<"$input") == "NO_TOOL_CALL" ]] || stop
# No workspace means nothing to gate; never fall back to the hook's own cwd.
dir=$(jq -er '.workspacePaths[0] | strings' <<<"$input" 2>/dev/null) || stop
# A later execution is agy continuing because of this gate: Claude's
# stop_hook_active, so the gate lets go instead of trapping the session.
active=$(jq '.executionNum > 1' <<<"$input")
reason=$(jq -n --arg cwd "$dir" --argjson active "$active" '{cwd: $cwd, stop_hook_active: $active}' |
  bash "$(dirname "${BASH_SOURCE[0]}")/../require-check.sh" 2>&1 >/dev/null) && stop
jq -n --arg reason "$reason" '{decision: "continue", reason: $reason}'
