#!/usr/bin/env bash
# Hidden check: utils/format.js formatDuration handles hours and bad input;
# CUtils.qml imports it, delegates to it and lints clean.
set -u
here=$(dirname "${BASH_SOURCE[0]}")
# shellcheck source=bench/worker/shared/qml.sh
source "$here/../../shared/qml.sh"
q=dotfiles/quickshell/.config/quickshell/utils
[[ -f $q/format.js ]] || {
  echo "missing $q/format.js"
  exit 1
}
qmllint_ok "$q/CUtils.qml" "$q/format.js" || exit 1
re='import[[:space:]]+"(\./)?format\.js"[[:space:]]+as[[:space:]]+([A-Za-z_][A-Za-z0-9_]*)'
[[ $(<"$q/CUtils.qml") =~ $re ]] || {
  echo "CUtils.qml does not import format.js"
  exit 1
}
qualifier=${BASH_REMATCH[2]}
[[ $(<"$q/CUtils.qml") == *"$qualifier.formatDuration("* ]] || {
  echo "CUtils.qml does not call $qualifier.formatDuration"
  exit 1
}
LIB=$q/format.js js_test "$here/hidden/format.test.mjs"
