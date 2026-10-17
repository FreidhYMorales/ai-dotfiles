#!/usr/bin/env bash
# Hidden check: a '%' without two hex digits is kept literally, with no reads
# past the end (ASan); valid escapes and url_encode unchanged.
set -u
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
gcc -std=c11 -Wall -Wextra -O1 -g -fsanitize=address,undefined -fno-sanitize-recover=all \
  -I src -o "$tmp/hidden" "$(dirname "${BASH_SOURCE[0]}")/hidden/hidden.c" src/url.c || exit 1
"$tmp/hidden"
