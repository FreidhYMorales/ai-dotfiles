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
  commit_journal
  machine_record
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
    mver=$(jq -r --arg t "$t" '.tools[$t].source | .tag // .version // ((.commit // "-") | .[0:7])' "$MANIFEST")
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
    # ✔ every tool active, ◐ some, · none.
    local on=0 all=0 mark=·
    while read -r t; do
      all=$((all + 1))
      [[ -z ${ACTIVE[$t]:-} ]] || on=$((on + 1))
    done < <(jq -r --arg p "$p" '.packs[$p].tools[]' "$MANIFEST")
    ((on == 0)) || mark=◐
    ((on == 0 || on < all)) || mark=✔
    line=$(printf ' %-9s %s  %s' "$p" "$mark" "$(jq -r --arg p "$p" '.packs[$p].tools | join(", ")' "$MANIFEST")")
    cut70 "$line"
  done < <(jq -r '.packs | keys[]' "$MANIFEST")
  say " -- tools --"
  for line in "${LINES[@]}"; do cut70 "$line"; done
}

# hint_signal PACK DEPS: print the dependency or file of the project root that matched
# PACK's detect rules; fail when none did.
hint_signal() {
  local p=$1 deps=$2 dep f
  while read -r dep; do
    if jq -e --arg d "$dep" 'index($d) != null' <<<"$deps" >/dev/null; then
      printf '%s\n' "$dep"
      return 0
    fi
  done < <(jq -r --arg p "$p" '.packs[$p].detect.package_deps_any // [] | .[]' "$MANIFEST")
  while read -r f; do
    [[ -f $KEY/$f ]] && {
      printf '%s\n' "$f"
      return 0
    }
  done < <(jq -r --arg p "$p" '.packs[$p].detect.files_any // [] | .[]' "$MANIFEST")
  return 1
}

# hint_due PACK HINTS: succeed when PACK was not shown in this project within 30 days.
hint_due() {
  jq -e --arg k "$KEY" --arg p "$1" --argjson now "$HINT_NOW" \
    '(.projects[$k][$p] // 0) as $t | $now - $t >= 2592000' <<<"$2" >/dev/null
}

# hint_main [--cwd DIR]: print "v1<TAB>message" for each pack worth suggesting; see cmd_hint.
hint_main() {
  parse_cwd_args "$@"
  HINT_NOW=${AI_PACK_NOW:-$(date +%s)}
  local file=$STATE_DIR/hints.json hints pj ig deps="[]" p sig t found
  local -a due=() sigs=()
  hints=$(state_read "$file") || return 0
  jq -e --argjson s "$STATE_SCHEMA" '(.schema_version // 0) > $s' <<<"$hints" >/dev/null && return 0
  pj=$(state_read "$STATE_DIR/projects.json") || return 0
  ig=$(state_read "$STATE_DIR/ignored.json") || return 0
  if [[ -f $KEY/package.json ]]; then
    deps=$(jq -c '[(.dependencies // {}), (.devDependencies // {}) | keys[]]' "$KEY/package.json" 2>/dev/null) || return 0
  fi
  while read -r p; do
    jq -e --arg k "$KEY" --arg p "$p" '(.projects[$k] // []) | index($p) != null' <<<"$ig" >/dev/null && continue
    found=0
    while read -r t; do
      jq -e --arg k "$KEY" --arg t "$t" '.projects[$k].tools[$t] != null' <<<"$pj" >/dev/null && found=1
    done < <(jq -r --arg p "$p" '.packs[$p].tools[]' "$MANIFEST")
    ((found == 0)) || continue
    sig=$(hint_signal "$p" "$deps") || continue
    hint_due "$p" "$hints" || continue
    due+=("$p")
    sigs+=("$sig")
  done < <(jq -r '.packs | keys[]' "$MANIFEST")
  ((${#due[@]})) || return 0
  # Under the lock, re-read: a parallel session may have shown the hint meanwhile.
  lock_try || return 0
  hints=$(state_read "$file") || return 0
  local -a lines=()
  for t in "${!due[@]}"; do
    hint_due "${due[t]}" "$hints" || continue
    hints=$(jq --arg k "$KEY" --arg p "${due[t]}" --argjson now "$HINT_NOW" '.projects[$k][$p] = $now' <<<"$hints")
    lines+=("v1"$'\t'"${sigs[t]} detected: ai-pack add ${due[t]} (ai-pack ignore ${due[t]})")
  done
  ((${#lines[@]})) || return 0
  state_write "$file" "$hints" || return 0
  printf '%s\n' "${lines[@]}"
}

# cmd_hint [--cwd DIR]: startup suggestion. Prints one `v1<TAB>message` line per pack that
# the project's root package.json / index.html points to, unless the pack is ignored, any
# of its tools is active, or it was shown in the last 30 days. Every error is silence.
# Writes only hints.json (lock_try, temp file + mv).
cmd_hint() {
  (hint_main "$@") 2>/dev/null || true
  return 0
}
