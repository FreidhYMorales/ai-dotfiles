#!/usr/bin/env bash
# Hidden check: workspaces sort numerically (10+ after 9), scrolling follows
# that order, and the rest of the list logic is unchanged.
set -u
here=$(dirname "${BASH_SOURCE[0]}")
# shellcheck source=bench/worker/shared/qml.sh
source "$here/../../shared/qml.sh"
qmllint_ok utils/workspaces.js modules/bar/WorkspacesWidget.qml || exit 1
LIB=utils/workspaces.js js_test "$here/hidden/workspaces.test.mjs"
