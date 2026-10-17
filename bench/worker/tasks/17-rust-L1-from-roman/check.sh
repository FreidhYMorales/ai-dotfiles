#!/usr/bin/env bash
# Hidden check: from_roman round-trips every number and rejects non-canonical
# numerals, on a copy of the crate with an extra integration test.
set -u
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
cp -a . "$tmp/crate" && rm -rf "$tmp/crate/.git" "$tmp/crate/target"
cp "$(dirname "${BASH_SOURCE[0]}")/hidden/hidden.rs" "$tmp/crate/tests/zz_hidden.rs"
cd "$tmp/crate" && cargo test --offline -q --test zz_hidden </dev/null
