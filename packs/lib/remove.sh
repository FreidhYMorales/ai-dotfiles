#!/usr/bin/env bash
# `ai-pack remove`: delete what ai-pack wrote, never what the user touched.
# Needs common.sh, state.sh, tree.sh, plan.sh. Source it; do not execute it.
# jq filters are single-quoted on purpose: $k, $t, $d and $p are jq variables.
# shellcheck disable=SC2016

# machine_save: write machine.json when it changed since the last save.
machine_save() {
  [[ $MACHINE == "$MACHINE0" ]] && return 0
  state_write "$STATE_DIR/machine.json" "$MACHINE"
  MACHINE0=$MACHINE
}

# machine_drop_dead TOOL: show and drop refcount entries whose project root is gone.
machine_drop_dead() {
  local p
  while IFS= read -r p; do
    [[ -d $p ]] && continue
    say "dropping dead project entry for $1: $p"
    MACHINE=$(jq -c --arg t "$1" --arg p "$p" 'del(.tools[$t].projects[]? | select(. == $p))' <<<"$MACHINE")
  done < <(jq -r --arg t "$1" '.tools[$t].projects[]?' <<<"$MACHINE")
}

# safe_rel REL: succeed when REL is a plain relative path that really lives at
# PROJ/REL (no empty, ".", "..", absolute path or symlinked component).
safe_rel() {
  local r=${1%/}
  [[ -n $r && $r != . && $r != /* && $r != ./* && $r != *..* ]] || return 1
  [[ $(realpath -m -- "$PROJ/$r") == "$PROJ/$r" ]]
}

# declared_dir REL: succeed when some tool in the manifest declares REL as a project dir.
declared_dir() {
  jq -e --arg d "$1" '[.tools[].project_dirs // {} | keys[]] | index($d)' "$MANIFEST" >/dev/null
}

# remove_dir TOOL REL: delete the journaled files of REL that still match, then
# REL itself if nothing but .gitignore is left. Hand edits and added files keep
# the whole dir; declared leftovers are printed and kept with their .gitignore.
remove_dir() {
  local t=$1 rel=$2 dir=$PROJ/$2 sha path p bad='' lo n=1 order=() left=() prune=()
  local -A listed=()
  if ! safe_rel "$rel" || ! declared_dir "${rel%/}"; then
    warn "$rel is not a declared dir or resolves outside the project; leaving it"
    return 0
  fi
  [[ -e $dir || -L $dir ]] || return 0
  [[ -d $dir && ! -L $dir ]] || {
    warn "$rel is not a directory; keeping it"
    return 0
  }
  while IFS=$'\t' read -r sha path; do
    listed[$path]=$sha
    order+=("$path")
  done < <(jq -r --arg k "$KEY" --arg t "$t" --arg d "$rel/" \
    '.projects[$k].tools[$t].files[]? | select(.path | startswith($d)) | [.sha256, .path] | @tsv' <<<"$PJ")
  mapfile -t left < <(jq -r --arg t "$t" --arg d "$rel/" '.tools[$t].leftovers[]? | select(startswith($d))' "$MANIFEST")
  for path in "${order[@]}"; do
    [[ $path == "$rel"/* && $path != *..* ]] && p=$(realpath -m -- "$(dirname "$PROJ/$path")") &&
      [[ $p == "$dir" || $p == "$dir"/* ]] || {
      warn "unsafe path $path in the journal; leaving $rel"
      return 0
    }
  done
  for path in "${order[@]}"; do
    [[ -e $PROJ/$path || -L $PROJ/$path ]] || continue
    [[ $(sha256sum -- "$PROJ/$path" | cut -d' ' -f1) == "${listed[$path]}" ]] || {
      bad=$path
      break
    }
  done
  if [[ -z $bad ]]; then
    while IFS= read -r -d '' p; do
      [[ -z ${listed[$p]:-} ]] || continue
      for lo in "${left[@]}"; do [[ $p == "$lo"/* ]] && continue 2; done
      bad=$p
      break
    done < <(cd "$PROJ" && find "$rel" \( -type f -o -type l \) ! -path "$rel/.gitignore" -print0)
  fi
  if [[ -z $bad && (-e $dir/.gitignore || -L $dir/.gitignore) ]]; then
    [[ -f $dir/.gitignore && ! -L $dir/.gitignore && $(<"$dir/.gitignore") == '*' ]] || bad=$rel/.gitignore
  fi
  if [[ -n $bad ]]; then
    warn "${bad##*/} was changed by hand ($bad); keeping $rel"
    say "delete $rel to re-add"
    return 0
  fi
  for path in "${order[@]}"; do rm -f -- "$PROJ/$path"; done
  for lo in "${left[@]}"; do prune+=(-path "$PROJ/$lo" -prune -o); done
  while ((n)); do
    n=0
    while IFS= read -r -d '' p; do rmdir -- "$p" && n=1; done \
      < <(find "$dir" -mindepth 1 "${prune[@]}" -type d -empty -print0)
  done
  if [[ -z $(find "$dir" -mindepth 1 ! -path "$dir/.gitignore" -print -quit) ]]; then
    rm -rf -- "$dir"
    say "removed $rel"
  else
    for lo in "${left[@]}"; do [[ -e $PROJ/$lo ]] && say "left in place: $lo/ (runtime output; delete it yourself)"; done
  fi
  return 0
}

# remove_created: rmdir the parent dirs `add` created, if still empty, then forget them.
remove_created_dirs() {
  local d
  while IFS= read -r d; do
    safe_rel "$d" && [[ $d == .claude || $d == .claude/* ]] && rmdir -- "$PROJ/$d" 2>/dev/null
  done < <(jq -r --arg k "$KEY" '.projects[$k].created[]?' <<<"$PJ" | LC_ALL=C sort -r)
  return 0
}

# cmd_remove PACK|TOOL [--purge] [--cwd DIR]
cmd_remove() {
  local purge=0 a t args=() drop=() keep=() via users=() p list
  for a in "$@"; do if [[ $a == --purge ]]; then purge=1; else args+=("$a"); fi; done
  parse_pack_args "${args[@]}"
  PROJ=$KEY
  resolve_targets "$PACK"
  lock_wait
  PJ=$(state_read "$STATE_DIR/projects.json") || exit 1
  MACHINE=$(state_read "$STATE_DIR/machine.json") || exit 1
  MACHINE0=$MACHINE
  for t in "${TOOLS[@]}"; do
    via=$(jq -r --arg k "$KEY" --arg t "$t" --arg v "$VIA" \
      'if .projects[$k].tools[$t] then ((.projects[$k].tools[$t].via // []) | if index($v) then (. - [$v] | join(",")) else ("!" + join(",")) end) else "-" end' <<<"$PJ")
    case $via in
      -) say "$t is not active in this project" ;;
      !*) say "$t is still needed by ${via#!}" && keep+=("$t") ;;
      "") drop+=("$t") ;;
      *) say "$t is still needed by $via" && keep+=("$t") ;;
    esac
  done
  if ((purge)); then
    for t in "${TOOLS[@]}"; do machine_drop_dead "$t"; done
    machine_save
    for t in "${TOOLS[@]}"; do
      mapfile -t users < <(jq -r --arg t "$t" --arg k "$KEY" '.tools[$t].projects[]? | select(. != $k)' <<<"$MACHINE")
      for p in "${keep[@]}"; do [[ $p == "$t" ]] && users+=("$KEY"); done
      ((${#users[@]} == 0)) && continue
      list=$(printf '%s, ' "${users[@]}")
      die "still used by ${list%, }; nothing removed"
    done
  fi
  clean_stages "$PROJ"
  for t in "${drop[@]}"; do
    while IFS= read -r p; do remove_dir "$t" "$p"; done \
      < <(jq -r --arg k "$KEY" --arg t "$t" '.projects[$k].tools[$t].dirs[]?' <<<"$PJ")
    PJ=$(jq -c --arg k "$KEY" --arg t "$t" 'del(.projects[$k].tools[$t])' <<<"$PJ")
    MACHINE=$(jq -c --arg k "$KEY" --arg t "$t" 'del(.tools[$t].projects[]? | select(. == $k))' <<<"$MACHINE")
  done
  if [[ $(jq -r --arg k "$KEY" '(.projects[$k].tools // {}) | length' <<<"$PJ") == 0 ]]; then
    remove_created_dirs
    PJ=$(jq -c --arg k "$KEY" 'del(.projects[$k])' <<<"$PJ")
  fi
  for t in "${keep[@]}"; do
    PJ=$(jq -c --arg k "$KEY" --arg t "$t" --arg v "$VIA" \
      '.projects[$k].tools[$t].via -= [$v]' <<<"$PJ")
  done
  if ((purge)); then
    for t in "${TOOLS[@]}"; do MACHINE=$(jq -c --arg t "$t" 'del(.tools[$t])' <<<"$MACHINE"); done
  fi
  state_write "$STATE_DIR/projects.json" "$PJ"
  machine_save
  say "ok: removed $PACK from $KEY"
}
