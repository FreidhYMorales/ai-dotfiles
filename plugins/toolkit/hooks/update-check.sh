#!/usr/bin/env bash
# SessionStart hook: notify (never install) when updates are available.
# - Installed Claude Code plugins older than their marketplace manifest
#   (e.g. a committed version bump that was never `claude plugin update`d).
# - The engram binary older than its latest GitHub release, looked up at most
#   once a day and never for longer than 3 seconds.
# - Claude Code differing from the version the installed look plugin is
#   pinned to, at most once a day.
# Any failure stays silent. Opt out with SKIP_UPDATE_CHECK=1.
set -u
# shellcheck source=plugins/toolkit/hooks/lib.sh
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh" && hook_off

[[ ${SKIP_UPDATE_CHECK:-} == 1 ]] && exit 0

input=$(cat)
[[ $(jq -r '.source // empty' <<<"$input" 2>/dev/null) == startup ]] || exit 0

PLUGINS_DIR=${CLAUDE_PLUGINS_DIR:-$HOME/.claude/plugins}
CACHE=${UPDATE_CHECK_CACHE:-${XDG_CACHE_HOME:-$HOME/.cache}/ai-dotfiles/engram-latest}
CACHE_TTL_SECS=86400
LOOKUP_FAILED=$(dirname "$CACHE")/engram-lookup-failed
LOOKUP_FAILED_TTL_SECS=3600
ENGRAM_RELEASE_API=https://api.github.com/repos/Gentleman-Programming/engram/releases/latest

# newer A B: true when version A is strictly newer than B.
newer() {
  [[ -n $1 && -n $2 && $1 != "$2" ]] &&
    [[ $(printf '%s\n%s\n' "$1" "$2" | sort -V | tail -n1) == "$1" ]]
}

notes=()

installed=$PLUGINS_DIR/installed_plugins.json
known=$PLUGINS_DIR/known_marketplaces.json
if [[ -f $installed && -f $known ]]; then
  while read -r key version; do
    name=${key%@*}
    marketplace=${key#*@}
    location=$(jq -r --arg m "$marketplace" '.[$m].installLocation // empty' "$known" 2>/dev/null)
    [[ -n $location ]] || continue
    available=$(jq -r --arg n "$name" \
      'first(.plugins[]? | select(.name == $n) | .version // empty)' \
      "$location/.claude-plugin/marketplace.json" 2>/dev/null)
    if newer "$available" "$version"; then
      notes+=("$key $version -> $available (claude plugin update $key)")
    fi
  done < <(jq -r '.plugins // {} | to_entries[] | "\(.key) \(.value[0].version // "")"' \
    "$installed" 2>/dev/null)
fi

if command -v engram >/dev/null 2>&1; then
  current=$(engram version 2>/dev/null | awk '{print $2}')
  current=${current#v}
  latest=""
  if [[ -f $CACHE ]] && (($(date +%s) - $(stat -c %Y "$CACHE") < CACHE_TTL_SECS)); then
    latest=$(<"$CACHE")
  elif [[ ! -f $LOOKUP_FAILED ]] || (($(date +%s) - $(stat -c %Y "$LOOKUP_FAILED") >= LOOKUP_FAILED_TTL_SECS)); then
    latest=$(curl -fsS --max-time 3 "$ENGRAM_RELEASE_API" 2>/dev/null | jq -r '.tag_name // empty' 2>/dev/null)
    latest=${latest#v}
    mkdir -p "$(dirname "$CACHE")"
    if [[ -n $latest ]]; then
      printf '%s\n' "$latest" >"$CACHE"
    else
      touch "$LOOKUP_FAILED"
    fi
  fi
  # A failed or waiting lookup falls back to the last version it knew.
  [[ -z $latest && -f $CACHE ]] && latest=$(<"$CACHE")
  if newer "$latest" "$current"; then
    notes+=("engram $current -> $latest (https://github.com/Gentleman-Programming/engram/releases)")
  fi
fi

# look pin: the installed look plugin is tested against one Claude Code
# version; any other installed version may break its band silently. Shown at
# most once a day.
LOOK_PIN_SHOWN=$(dirname "$CACHE")/look-pin-shown
if [[ -f $LOOK_PIN_SHOWN ]] && (($(date +%s) - $(stat -c %Y "$LOOK_PIN_SHOWN") < CACHE_TTL_SECS)); then
  :
elif [[ -f $installed ]]; then
  look_path=$(jq -r 'first(.plugins // {} | to_entries[] | select(.key | startswith("look@"))
    | .value[0].installPath // empty)' "$installed" 2>/dev/null)
  pin=$(cat "$look_path/tests/claude-code.version" 2>/dev/null)
  claude_version=$(claude --version 2>/dev/null | awk '{print $1}')
  if [[ -n $pin && -n $claude_version && $pin != "$claude_version" ]]; then
    notes+=("look pin $pin != Claude Code $claude_version (bump it: docs/look.md, \"Bump the pin\")")
    mkdir -p "$(dirname "$LOOK_PIN_SHOWN")" && touch "$LOOK_PIN_SHOWN"
  fi
fi

# Upstream news: only read what the daily upstream-watch timer recorded, so
# session start never waits on GitHub.
UPSTREAM_STATE=${UPSTREAM_WATCH_STATE:-${XDG_STATE_HOME:-$HOME/.local/state}/upstream-watch/state.json}
if [[ -f $UPSTREAM_STATE ]]; then
  news=$(jq -r '.changed // [] | map(.repo) | join(", ")' "$UPSTREAM_STATE" 2>/dev/null)
  [[ -n $news ]] && notes+=("upstreams with news: $news (run: upstream-watch)")
fi

((${#notes[@]})) || exit 0
message="Updates available:"
for note in "${notes[@]}"; do message+=$'\n'"  - $note"; done
jq -n --arg m "$message" '{systemMessage: $m}'
