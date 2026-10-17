#!/usr/bin/env bash
# Hidden check: a fake Gentoo host with only emerge reports it.
set -u
d=$(mktemp -d)
trap 'rm -rf "$d"' EXIT
mkdir -p "$d/bin"
bashbin=$(command -v bash)
printf '#!%s\necho Linux\n' "$bashbin" >"$d/bin/uname"
printf '#!%s\n' "$bashbin" >"$d/bin/emerge"
chmod +x "$d/bin/uname" "$d/bin/emerge"
ln -s "$(command -v jq)" "$d/bin/jq"
printf 'PRETTY_NAME="Gentoo Linux"\n' >"$d/os-release"
ctx=$(echo '{"source":"startup"}' | env -i PATH="$d/bin" SHELL=/bin/bash OS_RELEASE_FILE="$d/os-release" \
  PROC_VERSION_FILE="$d/none" "$bashbin" plugins/toolkit/hooks/host-info.sh | jq -r '.hookSpecificOutput.additionalContext')
[[ $ctx == *"packages: emerge"* ]] || {
  echo "got: $ctx"
  exit 1
}
