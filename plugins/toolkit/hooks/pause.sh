#!/usr/bin/env bash
# UserPromptSubmit hook: fast, safe pause.
# When the prompt starts with "pausa", "pausar" or "pause", it saves a
# checkpoint to engram itself (branch, uncommitted files, last commit) before
# Claude answers, then injects a short protocol: no new work, say what is still
# running and whether it is safe to stop, reply in a few lines.
# Opt out with SKIP_PAUSE_HOOK=1.
set -u

[[ ${SKIP_PAUSE_HOOK:-} == 1 ]] && exit 0

input=$(</dev/stdin)
prompt=$(jq -r '.prompt // empty' <<<"$input" 2>/dev/null)
cwd=$(jq -r '.cwd // empty' <<<"$input" 2>/dev/null)
prompt=${prompt,,}
prompt=${prompt#"${prompt%%[![:space:]]*}"}
[[ $prompt =~ ^(pausa|pausar|pause)([^a-z]|$) ]] || exit 0
[[ -d $cwd ]] || cwd=$PWD

checkpoint="Paused at $(date '+%Y-%m-%d %H:%M') in $cwd"
if branch=$(git -C "$cwd" branch --show-current 2>/dev/null); then
  status=$(git -C "$cwd" status --short 2>/dev/null | head -n 20)
  last=$(git -C "$cwd" log -1 --format='%h %s' 2>/dev/null)
  checkpoint+=$'\n'"branch: ${branch:-detached}"$'\n'"last commit: ${last:-none}"
  checkpoint+=$'\n'"uncommitted:"$'\n'"${status:-  (clean)}"
fi
if command -v engram >/dev/null 2>&1; then
  (cd "$cwd" && engram save "Pause checkpoint" "$checkpoint" --type manual --topic checkpoint/pause) \
    >/dev/null 2>&1 || true
fi

context="PAUSE REQUESTED. The user may close the terminal in seconds. A checkpoint was already saved to engram (topic checkpoint/pause). Do not start new work and make at most one more tool call. Reply in at most 5 lines: what was in progress, anything still running and whether it is safe to stop it (or how to stop it cleanly), uncommitted changes, and how to resume: reattach with \`cz\` from the project (the session keeps running if Claude was started with cz), or \`cz --continue\` / \`claude --continue\` after a reboot."

jq -n --arg ctx "$context" \
  '{hookSpecificOutput: {hookEventName: "UserPromptSubmit", additionalContext: $ctx}}'
