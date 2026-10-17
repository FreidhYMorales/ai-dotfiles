#!/usr/bin/env bash
# Gate for the QML tasks: every given .qml/.js file lints clean and every .js
# library parses under node. Usage: qml-gate.sh FILE...
set -u
# shellcheck source=bench/worker/shared/qml.sh
source "$(dirname "${BASH_SOURCE[0]}")/qml.sh"
qmllint_ok "$@" || exit 1
for f in "$@"; do
  [[ $f == *.js ]] || continue
  node --input-type=module -e "
    const { loadLibrary } = await import(process.argv[1]);
    loadLibrary(process.argv[2]);" "$QML_SHARED/pragma.mjs" "$f" || exit 1
done
