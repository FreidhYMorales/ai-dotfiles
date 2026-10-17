#!/usr/bin/env bash
# Hidden check: Last() is the newest sample before and after wrap-around, on a
# copy of the package with an extra test file.
set -u
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
cp -a . "$tmp/pkg" && rm -rf "$tmp/pkg/.git"
cp "$(dirname "${BASH_SOURCE[0]}")/hidden/hidden_test.go" "$tmp/pkg/zz_hidden_test.go"
cd "$tmp/pkg" && go test -count=1 -run 'Hidden' -v ./...
