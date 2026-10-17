#!/usr/bin/env bash
# Helpers for the QML tasks' hidden checks. Source it; do not execute it.
# QML cannot run headless here, so checks lint the .qml files and run the JS
# logic (`.pragma library` files) under node via pragma.mjs.

QML_SHARED=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)

# qmllint_ok FILE...: qmllint (Qt 6 when installed) reports no errors, no
# syntax problems and no missing JS/QML imports. Warnings are fine.
qmllint_ok() {
  local bin out rc
  for bin in /usr/lib/qt6/bin/qmllint qmllint6 qmllint; do
    command -v "$bin" >/dev/null 2>&1 && break
  done
  out=$("$bin" "$@" 2>&1)
  rc=$?
  if ((rc != 0)) || [[ $out == *"[syntax]"* || $out == *"you are trying to import does not exist"* ]]; then
    printf 'qmllint %s failed (exit %d):\n%s\n' "$*" "$rc" "$out"
    return 1
  fi
}

# js_test FILE.mjs: run a hidden node test (it imports $QML_SHARED/pragma.mjs).
js_test() {
  QML_SHARED=$QML_SHARED node --test --test-reporter=spec "$1"
}
