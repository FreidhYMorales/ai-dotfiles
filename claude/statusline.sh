#!/usr/bin/env bash
# Claude Code status line: meters first, then the place, on one line:
#   ctx BAR N% · 5h BAR N% [↻HH:MM] · 7d BAR N% · model · repo ⎇ branch[*]
# Reads the session JSON on stdin. Each meter is a 6-cell eighth-block bar
# with a dim track; colors: green < 50%, yellow < 80%, red from 80%.
# The host truncates on the right, so the place goes last and narrow panes
# lose the end of the branch before any meter.
set -u

IFS=$'\x1f' read -r model dir ctx five resets seven < <(jq -r '[
    (.model.display_name // "Claude" | sub("^Claude "; "")),
    .workspace.current_dir // .cwd // "",
    (.context_window.used_percentage // 0 | floor),
    (.rate_limits.five_hour.used_percentage // "" | if . == "" then "" else floor end),
    (.rate_limits.five_hour.resets_at // ""),
    (.rate_limits.seven_day.used_percentage // "" | if . == "" then "" else floor end)
  ] | map(tostring) | join("\u001f")' 2>/dev/null || printf 'Claude\x1f\x1f0\x1f\x1f\x1f\n')

dim=$'\e[2m'
reset=$'\e[0m'
partials=(▏ ▎ ▍ ▌ ▋ ▊ ▉)

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

# bar PCT: 6 cells, 48 eighth-steps (integer math), dim track for the rest.
bar() {
  local pct=$(($1 > 100 ? 100 : $1)) steps full out="" i
  steps=$(((pct * 48 + 50) / 100))
  full=$((steps / 8))
  for ((i = 0; i < full; i++)); do out+="█"; done
  ((steps % 8)) && out+="${partials[steps % 8 - 1]}"
  printf '%s%s' "$out" "$dim"
  for ((i = ${#out}; i < 6; i++)); do printf '░'; done
}

# meter LABEL PCT: colored "LABEL BAR PCT%"; the track is dim.
meter() {
  printf '%s%s %s%s %s%%%s' "$(color "$2")" "$1" "$(bar "$2")" "$(color "$2")" "$2" "$reset"
}

# trunc STR MAX: STR cut to MAX characters, ending in … when cut.
trunc() {
  if ((${#1} > $2)); then printf '%s…' "${1:0:$2-1}"; else printf '%s' "$1"; fi
}

parts=("$(meter ctx "$ctx")")

if [[ -n $five ]]; then
  quota=$(meter 5h "$five")
  if ((five >= 80)) && [[ -n $resets ]]; then
    quota+=" ↻$(date -d "@$resets" +%H:%M 2>/dev/null)"
  fi
  parts+=("$quota")
fi
[[ -n $seven ]] && parts+=("$(meter 7d "$seven")")

parts+=("$model")

if [[ -n $dir ]]; then
  if root=$(git -C "$dir" rev-parse --show-toplevel 2>/dev/null); then
    branch=$(git -C "$dir" branch --show-current 2>/dev/null)
    branch=$(trunc "${branch:-detached}" 20)
    [[ -n $(git -C "$dir" status --porcelain 2>/dev/null | head -n1) ]] && branch+="*"
    parts+=("$(trunc "${root##*/}" 16) ⎇ $branch")
  else
    parts+=("$(trunc "${dir##*/}" 16)")
  fi
fi

line=""
for part in "${parts[@]}"; do line+="${line:+ · }$part"; done
printf '%s' "$line"
