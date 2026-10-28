#!/usr/bin/env bash
# Antigravity PreToolUse adapter for prefer-modern-cli.sh: turns agy's payload
# into the Claude hook's input and its block into agy's deny. Anything else
# answers "ask", which keeps agy's own permission flow ("allow" would skip it).
# Fails closed: a payload it cannot read is denied.

input=$(cat)
ask() {
  echo '{"decision": "ask"}'
  exit 0
}
malformed() {
  echo '{"decision": "deny", "reason": "toolkit: malformed PreToolUse payload"}'
  exit 0
}

tool=$(jq -er '.toolCall.name | strings' <<<"$input" 2>/dev/null) || malformed
[[ $tool == "run_command" ]] || ask
cmd=$(jq -er '.toolCall.args.CommandLine | strings' <<<"$input" 2>/dev/null) || malformed
reason=$(jq -n --arg cmd "$cmd" '{tool_name: "Bash", tool_input: {command: $cmd}}' |
  bash "$(dirname "${BASH_SOURCE[0]}")/../prefer-modern-cli.sh" 2>&1 >/dev/null) && ask
jq -n --arg reason "$reason" '{decision: "deny", reason: $reason}'
