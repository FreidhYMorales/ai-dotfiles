#!/usr/bin/env bash
# SessionStart hook: speak up only when the engram backup needs attention.
# Reads the status files bin/engram-backup writes (backup.json, verify.json)
# and warns when the last run failed, the last backup is older than 2 days,
# the last verify is older than 8 days, or nothing was ever recorded.
# Silent when engram-backup is not configured. Opt out with SKIP_BACKUP_STATUS=1.
set -u
# shellcheck source=plugins/toolkit/hooks/lib.sh
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh" && hook_off

[[ ${SKIP_BACKUP_STATUS:-} == 1 ]] && exit 0

IFS= read -r -d '' input || true
[[ $(jq -r '.source // empty' <<<"$input" 2>/dev/null) == startup ]] || exit 0

CONFIG=${XDG_CONFIG_HOME:-$HOME/.config}/restic/engram.env
STATE_DIR=${XDG_STATE_HOME:-$HOME/.local/state}/engram-backup
MAX_BACKUP_DAYS=2
MAX_VERIFY_DAYS=8

[[ -f $CONFIG ]] || exit 0

# check MODE MAX_DAYS LABEL: append a note when MODE's status needs attention.
notes=()
check() {
  local file="$STATE_DIR/$1.json" max=$2 label=$3 ok time failed days
  [[ -f $file ]] || return 1
  ok=$(jq -r '.ok' "$file" 2>/dev/null)
  time=$(jq -r '.time // empty' "$file" 2>/dev/null)
  failed=$(jq -r '.failed // [] | join(", ")' "$file" 2>/dev/null)
  if [[ $ok != true ]]; then
    notes+=("$label FAILED at $time: ${failed:-unknown repository}")
    return 0
  fi
  days=$((($(date +%s) - $(date -d "$time" +%s 2>/dev/null || echo 0)) / 86400))
  if ((days > max)); then
    case $1 in
      backup) notes+=("last engram backup was $days days ago (timer: systemctl --user status engram-backup.timer)") ;;
      verify) notes+=("engram backups last verified $days days ago (run: engram-backup --verify)") ;;
    esac
  fi
  return 0
}

check backup "$MAX_BACKUP_DAYS" "engram backup" ||
  notes+=("no engram backup recorded yet (run: engram-backup)")
check verify "$MAX_VERIFY_DAYS" "engram backup verify" || true

((${#notes[@]})) || exit 0
message="Backup attention:"
for note in "${notes[@]}"; do message+=$'\n'"  - $note"; done
jq -n --arg m "$message" '{systemMessage: $m}'
