#!/usr/bin/env bash
# Shared helpers for ai-pack. Source it; do not execute it.

say() { printf '%s\n' "$*"; }
warn() { printf 'warning: %s\n' "$*" >&2; }
die() {
  printf 'error: %s\n' "$*" >&2
  exit 1
}
usage_error() {
  printf 'error: %s (see ai-pack --help)\n' "$*" >&2
  exit 2
}

# require_cmd CMD PACKAGE: succeed when CMD exists, else print the pacman line.
require_cmd() {
  command -v "$1" >/dev/null 2>&1 && return 0
  printf '%s not found; install it with: sudo pacman -S %s\n' "$1" "$2" >&2
  return 1
}

# check_deps: every tool ai-pack itself needs; reports all that are missing.
check_deps() {
  local missing=0
  require_cmd jq jq || missing=1
  require_cmd flock util-linux || missing=1
  require_cmd curl curl || missing=1
  require_cmd sha256sum coreutils || missing=1
  return "$missing"
}

# version_ge A B: succeed when version A >= version B (sort -V order).
version_ge() {
  [[ $(printf '%s\n%s\n' "$2" "$1" | sort -V | head -n1) == "$2" ]]
}

# project_key [DIR]: git root realpath of DIR (default $PWD), else DIR's realpath.
project_key() {
  local dir top
  dir=$(realpath -- "${1:-$PWD}" 2>/dev/null) || die "no such directory: ${1:-$PWD}"
  if top=$(env -u GIT_DIR -u GIT_WORK_TREE -u GIT_COMMON_DIR git -C "$dir" rev-parse --show-toplevel 2>/dev/null); then
    realpath -- "$top"
  else
    printf '%s\n' "$dir"
  fi
}
