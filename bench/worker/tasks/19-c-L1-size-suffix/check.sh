#!/usr/bin/env bash
# Hidden check: K/M/G/T suffixes, case, overflow after scaling, bad input.
# Builds the repo's src/size.c with a hidden test under ASan/UBSan.
set -u
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
gcc -std=c11 -Wall -Wextra -O1 -g -fsanitize=address,undefined -fno-sanitize-recover=all \
  -I src -o "$tmp/hidden" "$(dirname "${BASH_SOURCE[0]}")/hidden/hidden.c" src/size.c || exit 1
"$tmp/hidden"
