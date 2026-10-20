#!/usr/bin/env bash
# Pinned remote sources for ai-pack. Needs common.sh. Source it; do not execute it.

# fetch_verified URL SHA256 DEST: download URL to DEST and check its sha256.
# DEST is removed and the run dies on a network error or a mismatch.
fetch_verified() {
  local url=$1 sha=$2 dest=$3
  [[ $url == https://* ]] || die "$url: only https:// sources are allowed (nothing was written)"
  curl -fsSL --proto '=https' --proto-redir '=https' --max-time 60 -o "$dest" -- "$url" || {
    rm -f "$dest"
    die "$url: download failed (nothing was written)"
  }
  [[ $(sha256sum -- "$dest" | cut -d' ' -f1) == "$sha" ]] || {
    rm -f "$dest"
    die "$url: sha256 mismatch (nothing was written)"
  }
}

# npm_pack_verified PKG VER INTEGRITY DEST: `npm pack` into DEST, check the
# tarball's sha512 against the pinned npm integrity; print the tarball path.
npm_pack_verified() {
  local pkg=$1 ver=$2 want=$3 dest=$4 tars got
  mkdir -p "$dest" || exit 1
  npm pack "$pkg@$ver" --pack-destination "$dest" >/dev/null 2>&1 || die "$pkg@$ver: npm pack failed (nothing was written)"
  tars=("$dest"/*.tgz)
  [[ ${#tars[@]} -eq 1 && -f ${tars[0]} ]] || die "$pkg@$ver: npm pack produced no single tarball (nothing was written)"
  got=sha512-$(sha512sum -- "${tars[0]}" | cut -d' ' -f1 | tr a-f A-F | basenc --base16 -d | base64 -w0)
  [[ $got == "$want" ]] || die "$pkg@$ver: integrity mismatch (nothing was written)"
  printf '%s\n' "${tars[0]}"
}

# npm_install_prefix PREFIX TARBALL: install into PREFIX.staging, then mv -T to PREFIX.
# A failure removes the staging prefix. The caller owns the undo of PREFIX.
npm_install_prefix() {
  local prefix=$1 stage=$1.staging
  npm_owned "$stage" || die "unsafe npm prefix: $stage"
  rm -rf -- "$stage"
  mkdir -p "$stage" || die "cannot create $stage"
  npm install --prefix "$stage" --ignore-scripts --no-audit --no-fund "$2" >/dev/null 2>&1 || {
    rm -rf -- "$stage"
    die "npm install failed for $prefix; nothing was changed"
  }
  mv -T -- "$stage" "$prefix" || {
    rm -rf -- "$stage"
    die "cannot move $stage into place"
  }
}

# link_set BIN TARGET: point $BIN_DIR/BIN at TARGET atomically (temp link + mv -T).
link_set() {
  local tmp=$BIN_DIR/.ai-pack-$1.tmp
  mkdir -p "$BIN_DIR" || return 1
  rm -f -- "$tmp"
  if ln -s -- "$2" "$tmp" && mv -T -- "$tmp" "$BIN_DIR/$1"; then return 0; fi
  rm -f -- "$tmp"
  return 1
}

# link_switch BIN TARGET: link_set, recording how to restore the previous link.
link_switch() {
  local link=$BIN_DIR/$1 prev=
  [[ -L $link ]] && prev=$(readlink -- "$link")
  link_set "$1" "$2" || die "cannot link $link"
  if [[ -n $prev ]]; then undo_push link_set "$1" "$prev"; else undo_push rm -f -- "$link"; fi
}
