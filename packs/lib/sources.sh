#!/usr/bin/env bash
# Pinned remote sources for ai-pack. Needs common.sh. Source it; do not execute it.

# fetch_verified URL SHA256 DEST: download URL to DEST and check its sha256.
# DEST is removed and the run dies on a network error or a mismatch.
fetch_verified() {
  local url=$1 sha=$2 dest=$3
  curl -fsSL --max-time 60 -o "$dest" -- "$url" || {
    rm -f "$dest"
    die "$url: download failed (nothing was written)"
  }
  [[ $(sha256sum -- "$dest" | cut -d' ' -f1) == "$sha" ]] || {
    rm -f "$dest"
    die "$url: sha256 mismatch (nothing was written)"
  }
}
