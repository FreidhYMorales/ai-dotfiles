#!/usr/bin/env bash
# Machine layer of kind npm: preflight, install, link, record, purge.
# Needs common.sh, state.sh, sources.sh, plan.sh, remove.sh. Source it; do not execute it.
# jq filters are single-quoted on purpose: $t, $v, $k and $p are jq variables.
# SC2034: RESTART is read by cmd.sh.
# shellcheck disable=SC2016,SC2034

NPM_TOOLS=()
declare -A NPM_TAR=()
RESTART=0

# npm_owned PATH: succeed when PATH is a real <tool>@<ver>[.staging] entry directly
# under NPM_ROOT. The only paths ai-pack ever removes.
npm_owned() {
  [[ ${1##*/} =~ ^[A-Za-z0-9._-]+@[A-Za-z0-9._+-]+$ && ! -L $1 &&
    $(realpath -m -- "${1%/*}") == "$(realpath -m -- "$NPM_ROOT")" ]]
}

# npm_prefix TOOL: the prefix of the manifest version.
npm_prefix() {
  printf '%s/%s@%s\n' "$NPM_ROOT" "$1" "$(jq -r --arg t "$1" '.tools[$t].source.version' "$MANIFEST")"
}

# npm_preflight TOOL: refuse foreign bin paths; verify the tarball if the version is not installed.
npm_preflight() {
  local t=$1 pkg ver integ b link prefix
  IFS=$'\t' read -r pkg ver integ < <(jq -r --arg t "$t" '.tools[$t].source | [.package, .version, .integrity] | @tsv' "$MANIFEST")
  [[ $t =~ ^[A-Za-z0-9._-]+$ && $ver =~ ^[A-Za-z0-9._+-]+$ ]] || die "$t: invalid tool name or version"
  while read -r b; do
    [[ $b =~ ^[A-Za-z0-9][A-Za-z0-9._-]*$ ]] || die "$t: invalid bin name $b"
    link=$BIN_DIR/$b
    [[ -e $link || -L $link ]] || continue
    jq -e --arg t "$t" --arg b "$b" '.tools[$t].bins[$b]' <<<"$MACHINE" >/dev/null && [[ -L $link && $(readlink -- "$link") == "$NPM_ROOT/$t@"* ]] ||
      die "refusing: $link exists and was not created by ai-pack (nothing was written)"
  done < <(jq -r --arg t "$t" '.tools[$t].bins[]?' "$MANIFEST")
  NPM_TOOLS+=("$t")
  prefix=$(npm_prefix "$t")
  if jq -e --arg t "$t" --arg v "$ver" '.tools[$t].versions[$v]' <<<"$MACHINE" >/dev/null && [[ -d $prefix ]]; then
    return 0
  fi
  [[ ! -e $prefix && ! -L $prefix ]] || die "refusing: $prefix exists but ai-pack did not record it; remove it and retry (nothing was written)"
  [[ -n $FETCH_DIR ]] || FETCH_DIR=$(mktemp -d) || exit 1
  NPM_TAR[$t]=$(npm_pack_verified "$pkg" "$ver" "$integ" "$FETCH_DIR/npm-$t") || exit 1
}

# apply_machine: install missing prefixes and switch the bin links (all undoable).
apply_machine() {
  local t prefix b target
  for t in "${NPM_TOOLS[@]}"; do
    prefix=$(npm_prefix "$t")
    if [[ -n ${NPM_TAR[$t]:-} ]]; then
      mkdir -p "$NPM_ROOT" || die "cannot create $NPM_ROOT"
      undo_push rm -rf -- "$prefix.staging"
      undo_push rm -rf -- "$prefix"
      npm_install_prefix "$prefix" "${NPM_TAR[$t]}"
    fi
    while read -r b; do
      target=$prefix/node_modules/.bin/$b
      [[ -L $BIN_DIR/$b && $(readlink -- "$BIN_DIR/$b") == "$target" ]] || link_switch "$b" "$target"
    done < <(jq -r --arg t "$t" '.tools[$t].bins[]?' "$MANIFEST")
  done
}

# machine_record: record the npm tools in MACHINE and write machine.json.
machine_record() {
  local t ver prefix old bins now=${AI_PACK_NOW:-$(date +%s)}
  for t in "${NPM_TOOLS[@]}"; do
    prefix=$(npm_prefix "$t")
    ver=${prefix##*@}
    old=$(jq -r --arg t "$t" '.tools[$t].current // empty' <<<"$MACHINE")
    bins=$(jq -c --arg t "$t" --arg p "$prefix" '[.tools[$t].bins[]? | {(.): ($p + "/node_modules/.bin/" + .)}] | add // {}' "$MANIFEST")
    MACHINE=$(jq -c --arg t "$t" --arg v "$ver" --arg p "$prefix" --argjson at "$now" --arg k "$KEY" --argjson b "$bins" \
      '.tools[$t].current = $v | .tools[$t].versions[$v] = {prefix: $p, at: $at}
       | .tools[$t].bins = ((.tools[$t].bins // {}) + $b)
       | .tools[$t].projects = (((.tools[$t].projects // []) + [$k]) | unique)' <<<"$MACHINE")
    [[ -z $old || $old == "$ver" ]] || RESTART=1
  done
  machine_save
}

# npm_purge TOOL: remove the prefixes and bin links ai-pack made for TOOL. A link
# is removed only if it still points into ai-pack's prefix; anything else stays.
npm_purge() {
  local t=$1 b p
  while IFS= read -r b; do
    [[ $b =~ ^[A-Za-z0-9][A-Za-z0-9._-]*$ && -L $BIN_DIR/$b && $(readlink -- "$BIN_DIR/$b") == "$NPM_ROOT/$t@"* ]] && rm -f -- "$BIN_DIR/$b"
  done < <(jq -r --arg t "$t" '.tools[$t].bins // {} | keys[]' <<<"$MACHINE")
  while IFS= read -r p; do
    if [[ $p == "$NPM_ROOT/$t@"* ]] && npm_owned "$p"; then
      rm -rf -- "$p" "$p.staging"
    else
      warn "leaving $p: not an ai-pack prefix"
    fi
  done < <(jq -r --arg t "$t" '.tools[$t].versions // {} | .[].prefix' <<<"$MACHINE")
}
