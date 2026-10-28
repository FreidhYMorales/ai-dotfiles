#!/usr/bin/env bash
# Antigravity Stop adapter for require-check.sh: turns agy's payload into the
# Claude hook's input and its block into agy's continue.

input=$(cat)
dir=$(jq -r '.workspacePaths[0]' <<<"$input")
reason=$(jq -n --arg cwd "$dir" '{cwd: $cwd}' |
  bash "$(dirname "${BASH_SOURCE[0]}")/../require-check.sh" 2>&1 >/dev/null)
jq -n --arg reason "$reason" '{decision: "continue", reason: $reason}'
