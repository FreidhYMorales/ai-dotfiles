#!/usr/bin/env bash
# Hidden check: shorthand #rgb colors work in mix/shade; bad input still errors.
set -u
exec luajit "$(dirname "${BASH_SOURCE[0]}")/hidden/check.lua"
