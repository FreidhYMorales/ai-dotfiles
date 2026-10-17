#!/usr/bin/env bash
# Hidden check: utils.lighten clamps; light kitty backgrounds darken the chrome.
set -u
exec luajit "$(dirname "${BASH_SOURCE[0]}")/hidden/check.lua"
