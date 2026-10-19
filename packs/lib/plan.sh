#!/usr/bin/env bash
# Plan and apply for `ai-pack add`: classify targets, move staged dirs, undo on
# failure. Needs common.sh, state.sh, tree.sh. Source it; do not execute it.
# jq filters are single-quoted on purpose: $t, $k and $d are jq variables.
# shellcheck disable=SC2016

UNDO=()
CREATED=()
PLAN=()
TOOLS=()

# undo_push CMD [ARGS...]: remember how to revert the step just done.
undo_push() { UNDO+=("$(printf '%q ' "$@")"); }

# undo_run: revert every recorded step, newest first.
undo_run() {
  local i
  for ((i = ${#UNDO[@]} - 1; i >= 0; i--)); do eval "${UNDO[i]}" || true; done
  UNDO=()
}

# mkdir_tracked DIR: mkdir -p, remembering the dirs it creates in CREATED.
mkdir_tracked() {
  local d=$1 missing=()
  while [[ ! -d $d ]]; do
    missing=("$d" "${missing[@]}")
    d=$(dirname "$d")
  done
  mkdir -p "$1" || exit 1
  CREATED+=("${missing[@]}")
}

# remove_created: rmdir the dirs this run created, newest first, if still empty.
remove_created() {
  local i
  for ((i = ${#CREATED[@]} - 1; i >= 0; i--)); do rmdir -- "${CREATED[i]}" 2>/dev/null || true; done
  CREATED=()
}

# resolve_targets NAME: set TOOLS (tool names) and VIA (pack name or "direct").
resolve_targets() {
  if jq -e --arg n "$1" '.packs[$n]' "$MANIFEST" >/dev/null 2>&1; then
    mapfile -t TOOLS < <(jq -r --arg n "$1" '.packs[$n].tools[]' "$MANIFEST")
    VIA=$1
  elif jq -e --arg n "$1" '.tools[$n]' "$MANIFEST" >/dev/null 2>&1; then
    TOOLS=("$1")
    VIA=direct
  else
    die "unknown pack or tool: $1"
  fi
}

# check_requires: every `requires` entry of TOOLS; print all problems, then fail.
check_requires() {
  local t c m h out v bad=0
  for t in "${TOOLS[@]}"; do
    while IFS=$'\t' read -r c m h; do
      if ! command -v "$c" >/dev/null 2>&1; then
        printf '%s not found; install it with: %s\n' "$c" "$h" >&2
        bad=1
      elif [[ $m != - ]]; then
        out=$("$c" --version 2>/dev/null)
        v=0
        [[ $out =~ ([0-9]+(\.[0-9]+)*) ]] && v=${BASH_REMATCH[1]}
        version_ge "$v" "$m" || {
          printf '%s %s is older than %s; install it with: %s\n' "$c" "$v" "$m" "$h" >&2
          bad=1
        }
      fi
    done < <(jq -r --arg t "$t" '.tools[$t].requires[]? | [.cmd, (.min // "-"), (.hint // "-")] | @tsv' "$MANIFEST")
  done
  ((bad == 0)) || die "requirements missing (nothing was written)"
}

# journal_files DIR_REL: JSON array of {path, sha256} for the files under DIR_REL.
journal_files() {
  local p
  (
    cd "$PROJ" || exit 1
    find "$1" \( -type f -o -type l \) ! -path "$1/.gitignore" -print0 | LC_ALL=C sort -z |
      while IFS= read -r -d '' p; do
        jq -n --arg p "$p" --arg s "$(sha256sum -- "$p" | cut -d' ' -f1)" '{path: $p, sha256: $s}'
      done | jq -s .
  )
}

# classify TOOL REL PINNED: print new|noop|replace|adopt|skip|refuse.
classify() {
  local tool=$1 rel=$2 pinned=$3 target=$PROJ/$2 cur sha path actual listed
  [[ -e $target || -L $target ]] || {
    echo new
    return
  }
  [[ -d $target && ! -L $target ]] || {
    echo refuse
    return
  }
  cur=$(tree_hash "$target") || return 1
  if jq -e --arg k "$KEY" --arg t "$tool" --arg d "$rel" \
    '.projects[$k].tools[$t].dirs // [] | index($d)' <<<"$PJ" >/dev/null; then
    while IFS=$'\t' read -r sha path; do
      [[ $(sha256sum -- "$PROJ/$path" 2>/dev/null | cut -d' ' -f1) == "$sha" ]] || {
        echo skip
        return
      }
    done < <(jq -r --arg k "$KEY" --arg t "$tool" --arg d "$rel/" \
      '.projects[$k].tools[$t].files[]? | select(.path | startswith($d)) | [.sha256, .path] | @tsv' <<<"$PJ")
    # A file the user added is a hand edit too: it would be lost on a swap.
    actual=$(cd "$PROJ" && find "$rel" \( -type f -o -type l \) ! -path "$rel/.gitignore" | LC_ALL=C sort)
    listed=$(jq -r --arg k "$KEY" --arg t "$tool" --arg d "$rel/" \
      '.projects[$k].tools[$t].files[]? | select(.path | startswith($d)) | .path' <<<"$PJ" | LC_ALL=C sort)
    [[ $actual == "$listed" ]] || {
      echo skip
      return
    }
    [[ $cur == "$pinned" ]] && echo noop || echo replace
  else
    [[ $cur == "$pinned" ]] && echo adopt || echo refuse
  fi
}

# load_plan: classify every project dir of TOOLS into PLAN (tool rel src pin action).
load_plan() {
  local t rel from pin tpl action src
  for t in "${TOOLS[@]}"; do
    [[ $(jq -r --arg t "$t" '.tools[$t].kind' "$MANIFEST") == skill ]] || die "$t: only skill tools are supported yet"
    while IFS=$'\t' read -r rel from pin tpl; do
      [[ $from == vendor:* && $tpl == - ]] || die "$t: only plain vendored sources are supported yet"
      src=$VENDOR_DIR/${from#vendor:}
      [[ -d $src ]] || die "$t: vendor dir missing: $src"
      action=$(classify "$t" "$rel" "$pin") || exit 1
      [[ $action != refuse ]] || die "refusing: $rel exists and is not an ai-pack copy (nothing was written)"
      [[ $action != skip ]] || warn "$rel was edited by hand; leaving it unchanged (delete it to re-sync)"
      PLAN+=("$t"$'\t'"$rel"$'\t'"$src"$'\t'"$pin"$'\t'"$action")
    done < <(jq -r --arg t "$t" '.tools[$t].project_dirs | to_entries[]
      | [.key, .value.from, .value.hash, (.value.template // "-")] | @tsv' "$MANIFEST")
  done
}

# apply_plan: stage, verify the pin, then move each dir into place.
apply_plan() {
  local entry t rel src pin action stage h
  for entry in "${PLAN[@]}"; do
    IFS=$'\t' read -r t rel src pin action <<<"$entry"
    [[ $action == new || $action == replace ]] || continue
    mkdir_tracked "$PROJ/.claude"
    stage=$(stage_new "$PROJ" "$src") || exit 1
    h=$(tree_hash "$stage") || exit 1
    [[ $h == "$pin" ]] || die "$t: staged $rel does not match its pinned hash"
    if [[ $action == new ]]; then
      mkdir_tracked "$(dirname "$PROJ/$rel")"
      mv -T "$stage" "$PROJ/$rel" || exit 1
      undo_push rm -rf "$PROJ/$rel"
    else
      mv -T --exchange "$stage" "$PROJ/$rel" || exit 1
      undo_push mv -T --exchange "$stage" "$PROJ/$rel"
    fi
  done
}

# commit_journal: record every tool of this run in projects.json (after the moves).
commit_journal() {
  local t tool entry rel action files dirs ver cur=$PJ now=${AI_PACK_NOW:-$(date +%s)}
  for t in "${TOOLS[@]}"; do
    files='[]' dirs='[]'
    for entry in "${PLAN[@]}"; do
      IFS=$'\t' read -r tool rel _ _ action <<<"$entry"
      [[ $tool == "$t" ]] || continue
      dirs=$(jq -c --arg d "$rel" '. + [$d]' <<<"$dirs")
      if [[ $action == skip ]]; then
        files=$(jq -c --argjson o "$PJ" --arg k "$KEY" --arg t "$t" --arg d "$rel/" \
          '. + [$o.projects[$k].tools[$t].files[]? | select(.path | startswith($d))]' <<<"$files")
      else
        files=$(jq -c --argjson n "$(journal_files "$rel")" '. + $n' <<<"$files")
      fi
    done
    ver=$(jq -r --arg t "$t" '.tools[$t].source.tag // "-"' "$MANIFEST")
    cur=$(jq -c --arg k "$KEY" --arg t "$t" --arg v "$ver" --arg via "$VIA" --argjson at "$now" \
      --argjson dirs "$dirs" --argjson files "$files" \
      '.projects[$k].tools[$t] = {version: $v, dirs: $dirs, files: $files, at: $at,
         via: (((.projects[$k].tools[$t].via // []) + [$via]) | unique)}' <<<"$cur")
  done
  state_write "$STATE_DIR/projects.json" "$cur"
}
