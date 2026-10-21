#!/usr/bin/env bash
# Mod gate for plugins/look: `claude plugin validate` and `claude plugin test`.
# Skips (exit 0) when claude is missing, unless LOOK_REQUIRE_CLAUDE=1 (CI sets
# it) makes that a failure. Warns when claude differs from claude-code.version.
# Neither command needs auth or the network. Run: bash plugins/look/tests/look.test.sh
set -u

here=${BASH_SOURCE[0]%/*}
[[ $here == "${BASH_SOURCE[0]}" ]] && here=.
here=$(cd "$here" && pwd)
plugin=${here%/tests}
pin=$(<"$here/claude-code.version")

if ! command -v claude >/dev/null 2>&1; then
  if [[ ${LOOK_REQUIRE_CLAUDE:-} == 1 ]]; then
    echo "FAIL: claude is not installed and LOOK_REQUIRE_CLAUDE=1" >&2
    exit 1
  fi
  echo "SKIP: claude is not installed; mod tests not run (pin $pin)"
  exit 0
fi

version=$(claude --version)
echo "claude ${version} (pin ${pin})"
[[ ${version%% *} == "$pin" ]] || echo "WARN: claude ${version%% *} differs from the pinned $pin; the mod API may have moved" >&2

# Isolate claude from the real home, config and state.
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
export HOME=$tmp XDG_CONFIG_HOME=$tmp/config XDG_STATE_HOME=$tmp/state XDG_DATA_HOME=$tmp/data

claude plugin validate "$plugin" || exit 1
claude plugin test "$plugin"
