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
  ((st == 0)) || warn "rolled back; nothing was written"
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
  load_plan
  apply_plan
  commit_journal
  UNDO=()
  clean_stages "$PROJ"
  say "ok: active ${TOOLS[*]} in $KEY"
  say "run /reload-plugins to load the new skills"
}
