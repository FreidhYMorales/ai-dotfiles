#!/usr/bin/env bash
# Hidden check: 7d segment appears only with data, after the 5h one.
set -u
strip() {
  local s=$1 re=$'\e\\[[0-9;]*m'
  while [[ $s =~ $re ]]; do s=${s/"${BASH_REMATCH[0]}"/}; done
  printf '%s' "$s"
}
both=$(echo '{"context_window":{"used_percentage":5},"rate_limits":{"five_hour":{"used_percentage":10},"seven_day":{"used_percentage":40.7}}}' | bash claude/statusline.sh)
only5=$(echo '{"context_window":{"used_percentage":5},"rate_limits":{"five_hour":{"used_percentage":10}}}' | bash claude/statusline.sh)
b=$(strip "$both")
o=$(strip "$only5")
[[ $b == *"7d 40%"* ]] || {
  echo "missing 7d: $b"
  exit 1
}
[[ $b == *"5h 10%"*"7d 40%"* ]] || {
  echo "7d not after 5h: $b"
  exit 1
}
[[ $o != *7d* ]] || {
  echo "7d shown without data: $o"
  exit 1
}
