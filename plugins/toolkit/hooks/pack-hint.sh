#!/usr/bin/env bash
# SessionStart hook: suggest an opt-in ai-pack when the project looks like it
# needs one. A thin wrapper over `ai-pack hint`, shown as systemMessage only
# (never additionalContext), so it costs no tokens.
# Silent when ai-pack is missing, slow (1.5 s) or fails. Opt out with
# AI_HOOKS_OFF=pack-hint.
set -u
# shellcheck source=plugins/toolkit/hooks/lib.sh
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh" && hook_off

# The read builtin, not $(</dev/stdin): that fails when stdin is a socket.
IFS= read -r -d '' input || true
[[ $(jq -r '.source // empty' <<<"$input" 2>/dev/null) == startup ]] || exit 0
cwd=$(jq -r '.cwd // empty' <<<"$input" 2>/dev/null)
[[ -n $cwd ]] || exit 0

bin=$(command -v ai-pack) || bin=${XDG_BIN_HOME:-$HOME/.local/bin}/ai-pack
[[ -x $bin ]] || exit 0
output=$(timeout 1.5 "$bin" hint --cwd "$cwd" 2>/dev/null) || exit 0

# Output contract: lines "v1<TAB>message"; anything else is dropped.
message=""
while IFS= read -r line; do
  [[ $line == v1$'\t'* ]] && message+="${message:+$'\n'}${line#v1$'\t'}"
done <<<"$output"
[[ -n $message ]] || exit 0
jq -n --arg m "$message" '{systemMessage: $m}'
