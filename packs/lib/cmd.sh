#!/usr/bin/env bash
# ai-pack subcommands. Needs common.sh, state.sh, tree.sh. Source it; do not execute it.
# jq filters are single-quoted on purpose: $k and $p are jq variables.
# SC2034: PJ and UNDO are read by plan.sh.
# shellcheck disable=SC2016,SC2034

cmd_hash() {
  [[ $# -eq 1 ]] || usage_error "usage: ai-pack hash DIR"
  tree_hash "$1"
}

# parse_pack_args PACK [--cwd DIR]: set PACK and KEY (the project key).
parse_pack_args() {
  PACK=${1:-}
  [[ -n $PACK ]] || usage_error "a pack name is required"
  shift
  parse_cwd_args "$@"
}

# parse_cwd_args [--cwd DIR]: set KEY (the project key).
parse_cwd_args() {
  local cwd=$PWD
  while [[ $# -gt 0 ]]; do
    case $1 in
      --cwd)
        [[ -n ${2:-} ]] || usage_error "--cwd needs a directory"
        cwd=$2
        shift 2
        ;;
      *) usage_error "unknown argument: $1" ;;
    esac
  done
  KEY=$(project_key "$cwd") || exit 1
}

# ignore_update FILTER: apply a jq filter to ignored.json under the lock.
ignore_update() {
  local file=$STATE_DIR/ignored.json cur
  lock_wait
  cur=$(state_read "$file") || exit 1
  state_write "$file" "$(jq --arg k "$KEY" --arg p "$PACK" "$1" <<<"$cur")"
}

cmd_ignore() {
  parse_pack_args "$@"
  ignore_update '.projects[$k] = (((.projects // {})[$k] // []) + [$p] | unique)'
  say "ignored $PACK in $KEY"
}

cmd_unignore() {
  parse_pack_args "$@"
  ignore_update '.projects[$k] = (((.projects // {})[$k] // []) - [$p])
    | if (.projects[$k] | length) == 0 then del(.projects[$k]) else . end'
  say "unignored $PACK in $KEY"
}

# add_cleanup: EXIT trap of `add`; roll back and drop stages when the run failed.
add_cleanup() {
  local st=$?
  undo_run
  clean_stages "$PROJ"
  [[ -z $FETCH_DIR ]] || rm -rf "$FETCH_DIR"
  ((st == 0)) || {
    remove_created
    warn "rolled back; nothing was written"
  }
  return "$st"
}

cmd_add() {
  parse_pack_args "$@"
  PROJ=$KEY
  resolve_targets "$PACK"
  check_requires
  lock_wait
  trap 'exit 130' INT TERM
  trap add_cleanup EXIT
  clean_stages "$PROJ"
  PJ=$(state_read "$STATE_DIR/projects.json") || exit 1
  MACHINE=$(state_read "$STATE_DIR/machine.json") || exit 1
  MACHINE0=$MACHINE
  load_plan
  warn_shadows
  apply_machine
  apply_plan
  machine_record
  commit_journal
  UNDO=()
  clean_stages "$PROJ"
  say "ok: active ${TOOLS[*]} in $KEY"
  say "run /reload-plugins to load the new skills"
  ((RESTART == 0)) || say "restart your Claude sessions to use the new machine version"
}

# cut70 LINE: print LINE cut to 70 characters, whatever the caller's locale.
cut70() {
  local out
  out=$(
    LC_ALL=C.UTF-8
    printf '%s' "${1:0:70}"
  )
  # Without a UTF-8 locale the cut is by bytes: drop a partial trailing character.
  while ! iconv -f UTF-8 -t UTF-8 <<<"$out" >/dev/null 2>&1; do out=${out%?}; done
  printf '%s\n' "$out"
}

# list_tool TOOL: append the display lines of TOOL to LINES; mark it in ACTIVE.
list_tool() {
  local t=$1 rel from pin tpl dirs=0 present=0 adopt=0 jver mver cur via sh mark=· detail="not added"
  while IFS=$'\t' read -r rel from pin tpl; do
    dirs=$((dirs + 1))
    [[ -d $PROJ/$rel ]] && present=$((present + 1))
    [[ $(classify "$t" "$rel" "$pin") == adopt ]] && adopt=$((adopt + 1))
    [[ $rel == .claude/skills/* && -z ${sh:-} ]] && sh=$(shadow_find "${rel##*/}" "$VENDOR_DIR/${from#vendor:}")
  done < <(tool_dirs "$t")
  jver=$(jq -r --arg k "$KEY" --arg t "$t" '.projects[$k].tools[$t].version // empty' <<<"$PJ")
  if [[ -n $jver && $present -eq $dirs ]]; then
    ACTIVE[$t]=1 mark=✔
    via=$(jq -r --arg k "$KEY" --arg t "$t" '.projects[$k].tools[$t].via // [] | join(",")' <<<"$PJ")
    detail="(via $via) $jver"
    mver=$(jq -r --arg t "$t" '.tools[$t].source | .tag // .version // "-"' "$MANIFEST")
    [[ $mver == - || $mver == "$jver" ]] || detail+=" -> $mver available"
    cur=$(jq -r --arg t "$t" '.tools[$t].current // empty' <<<"$MACHINE")
    [[ -z $cur || $cur == "$jver" ]] || detail+=" (machine $cur)"
  elif [[ -n $jver ]]; then
    detail="missing (ai-pack add $t)"
  elif ((dirs > 0 && adopt == dirs)); then
    detail="adoptable (ai-pack add $t)"
  fi
  LINES+=("$(printf ' %-*s %s %s' "$NAMEW" "$t" "$mark" "$detail")")
  [[ -z ${sh:-} ]] || LINES+=("   ⚠ shadowed by $sh")
}

# cmd_list [--cwd DIR]: read-only view of packs and tools; takes no lock and writes nothing.
cmd_list() {
  parse_cwd_args "$@"
  PROJ=$KEY
  local t p line mark
  local -A ACTIVE=()
  LINES=()
  NAMEW=$(jq -r '[.tools | keys[] | length] | (max // 1) | if . > 24 then 24 else . end' "$MANIFEST")
  PJ=$(state_read "$STATE_DIR/projects.json") || exit 1
  MACHINE=$(state_read "$STATE_DIR/machine.json") || exit 1
  while read -r t; do list_tool "$t"; done < <(jq -r '.tools | keys[]' "$MANIFEST")
  while read -r p; do
    mark=·
    while read -r t; do [[ -z ${ACTIVE[$t]:-} ]] || mark=✔; done < <(jq -r --arg p "$p" '.packs[$p].tools[]' "$MANIFEST")
    line=$(printf ' %-9s %s  %s' "$p" "$mark" "$(jq -r --arg p "$p" '.packs[$p].tools | join(", ")' "$MANIFEST")")
    cut70 "$line"
  done < <(jq -r '.packs | keys[]' "$MANIFEST")
  say " -- tools --"
  for line in "${LINES[@]}"; do cut70 "$line"; done
}
