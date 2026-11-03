#!/usr/bin/env bash
# PreToolUse hook (matcher: Bash): block commands that name a credential file.
# Exit 0 = allow, exit 2 = block (stderr is shown to Claude).
set -u

command -v jq >/dev/null 2>&1 || exit 0

input=$(cat)
cmd=$(jq -r '.tool_input.command // empty' <<<"$input" 2>/dev/null) || exit 0

if [[ $cmd == *.config/gh* ]]; then
  echo "Blocked: the command names a protected credential path (.config/gh)." >&2
  exit 2
fi
exit 0
