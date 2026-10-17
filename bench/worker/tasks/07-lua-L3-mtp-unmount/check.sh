#!/usr/bin/env bash
# Hidden check: unmount with no mount dir warns and runs no fusermount;
# real mounts still unmount; mount still works.
set -u
exec lua "$(dirname "${BASH_SOURCE[0]}")/hidden/check.lua"
