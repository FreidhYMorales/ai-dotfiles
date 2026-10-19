#!/usr/bin/env bash
# Tree hashing for ai-pack. Source it; do not execute it.

# normalize_modes DIR: dirs 755, files 644 (755 when the owner can execute).
normalize_modes() {
  find "$1" -type d -exec chmod 755 {} +
  find "$1" -type f -perm -u+x -exec chmod 755 {} +
  find "$1" -type f ! -perm -u+x -exec chmod 644 {} +
}

# tree_hash DIR: print sha256:<hex> over one NUL-delimited line per entry,
# "type x path sha256", NUL-sorted by path. Everything but the top-level
# .gitignore counts. type is f/d/l; x is the owner exec bit of files.
tree_hash() {
  [[ -d $1 ]] || die "not a directory: $1"
  local p t x h
  local digest
  digest=$(
    cd "$1" || exit 1
    find . -mindepth 1 ! -path ./.gitignore -print0 | LC_ALL=C sort -z |
      while IFS= read -r -d '' p; do
        x=0 h=-
        if [[ -L $p ]]; then
          t=l
          h=$(readlink -n -- "$p" | sha256sum | cut -d' ' -f1)
        elif [[ -d $p ]]; then
          t=d
        else
          t=f
          h=$(sha256sum -- "$p" | cut -d' ' -f1)
          [[ -x $p ]] && x=1
        fi
        printf '%s\0%s\0%s\0%s\n' "$t" "$x" "$p" "$h"
      done | sha256sum | cut -d' ' -f1
  ) || die "cannot hash $1"
  printf 'sha256:%s\n' "$digest"
}
