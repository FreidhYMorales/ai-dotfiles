#!/usr/bin/env bash
# Antigravity SessionStart adapter for the Claude session-start hooks: runs
# them with agy's workspace and joins what they say into one injected system
# message (agy has no user-only channel, so messages go there too).

input=$(cat)
hooks="$(dirname "${BASH_SOURCE[0]}")/.."
dir=$(jq -r '.workspacePaths[0]' <<<"$input")
payload=$(jq -n --arg cwd "$dir" '{source: "startup", cwd: $cwd}')

parts=()
for hook in host-info pack-hint backup-status; do
  out=$(bash "$hooks/$hook.sh" <<<"$payload" 2>/dev/null)
  text=$(jq -r '.hookSpecificOutput.additionalContext // .systemMessage // empty' <<<"$out" 2>/dev/null)
  [[ -n $text ]] && parts+=("$text")
done

message=$(printf '%s\n\n' "${parts[@]}")
jq -n --arg m "${message%$'\n\n'}" '{injectSteps: [{systemMessage: {systemMessage: $m}}]}'
