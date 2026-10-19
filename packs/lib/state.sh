#!/usr/bin/env bash
# State files for ai-pack: JSON with schema_version 1, written via temp + mv
# under flock. Needs STATE_DIR and common.sh. Source it; do not execute it.

STATE_SCHEMA=1

# state_read FILE: print the JSON ({} when the file is absent); fail when corrupt.
state_read() {
  [[ -f $1 ]] || {
    printf '{}\n'
    return 0
  }
  jq -c . "$1" 2>/dev/null || die "state file is corrupt: $1"
}

# state_write FILE JSON: refuse a newer schema, else replace FILE atomically.
state_write() {
  local file=$1 json=$2 current tmp
  current=$(state_read "$file") || return 1
  if jq -e --argjson s "$STATE_SCHEMA" '(.schema_version // 0) > $s' <<<"$current" >/dev/null; then
    die "$file has a newer schema_version; update ai-pack (nothing was written)"
  fi
  tmp=$(mktemp "$file.XXXXXX") || die "cannot write $file"
  if ! jq --argjson s "$STATE_SCHEMA" '.schema_version = $s' <<<"$json" >"$tmp"; then
    rm -f "$tmp"
    die "invalid state for $file"
  fi
  mv -f "$tmp" "$file"
}

# lock_wait: take the state lock on fd 9, waiting AI_PACK_LOCK_WAIT seconds (30).
lock_wait() {
  mkdir -p "$STATE_DIR" || die "cannot create $STATE_DIR"
  exec 9>"$STATE_DIR/lock" || die "cannot open $STATE_DIR/lock"
  flock -w "${AI_PACK_LOCK_WAIT:-30}" 9 || die "another ai-pack run holds the lock; try again"
}

# lock_try: take the state lock without waiting; fail when it is held.
lock_try() {
  mkdir -p "$STATE_DIR" || return 1
  exec 9>"$STATE_DIR/lock" || return 1
  flock -n 9
}
