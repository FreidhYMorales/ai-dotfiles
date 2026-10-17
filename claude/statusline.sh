#!/usr/bin/env bash
# Claude Code status line: model, project, git branch, context use, 5-hour
# plan quota and zellij session, on one line. Reads the session JSON on stdin.
# Colors: green < 50%, yellow < 80%, red from 80% (context and quota).
set -u

IFS=$'\x1f' read -r model dir ctx five resets < <(jq -r '[
    .model.display_name // "Claude",
    .workspace.current_dir // .cwd // "",
    (.context_window.used_percentage // 0 | floor),
    (.rate_limits.five_hour.used_percentage // "" | if . == "" then "" else floor end),
    (.rate_limits.five_hour.resets_at // "")
  ] | map(tostring) | join("\u001f")' 2>/dev/null || printf 'Claude\x1f\x1f0\x1f\x1f\n')

dim=$'\e[2m'
reset=$'\e[0m'
# color PCT: ANSI color for a usage percentage.
color() {
  if (($1 >= 80)); then
    printf '\e[31m'
  elif (($1 >= 50)); then
    printf '\e[33m'
  else
    printf '\e[32m'
  fi
}

parts=("$model")

if [[ -n $dir ]]; then
  if root=$(git -C "$dir" rev-parse --show-toplevel 2>/dev/null); then
    branch=$(git -C "$dir" branch --show-current 2>/dev/null)
    [[ -n $(git -C "$dir" status --porcelain 2>/dev/null | head -n1) ]] && branch+="*"
    parts+=("${root##*/} ⎇ ${branch:-detached}")
  else
    parts+=("${dir##*/}")
  fi
fi

filled=$(((ctx * 6 + 50) / 100))
bar=""
for ((i = 0; i < 6; i++)); do
  if ((i < filled)); then bar+="▓"; else bar+="░"; fi
done
parts+=("$(color "$ctx")ctx $ctx%$reset $bar")

if [[ -n $five ]]; then
  quota="$(color "$five")5h $five%$reset"
  [[ -n $resets ]] && quota+=" ${dim}(resets $(date -d "@$resets" +%H:%M 2>/dev/null))$reset"
  parts+=("$quota")
fi

[[ -n ${ZELLIJ_SESSION_NAME:-} ]] && parts+=("${dim}zj $ZELLIJ_SESSION_NAME$reset")

line=""
for part in "${parts[@]}"; do line+="${line:+ · }$part"; done
printf '%s' "$line"
