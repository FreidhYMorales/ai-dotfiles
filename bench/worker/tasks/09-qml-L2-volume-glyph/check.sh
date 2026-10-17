#!/usr/bin/env bash
# Hidden check: utils/volume.js volumeGlyph covers mute, zero, boost and the
# old thresholds; both QML files use it instead of their own glyph ternary.
set -u
here=$(dirname "${BASH_SOURCE[0]}")
# shellcheck source=bench/worker/shared/qml.sh
source "$here/../../shared/qml.sh"
q=dotfiles/quickshell/.config/quickshell
lib=$q/utils/volume.js
[[ -f $lib ]] || {
  echo "missing $lib"
  exit 1
}
qmllint_ok "$lib" "$q/modules/bar/VolumeWidget.qml" "$q/modules/bar/Osd.qml" || exit 1
re='import[[:space:]]+"\.\./\.\./utils/volume\.js"[[:space:]]+as[[:space:]]+([A-Za-z_][A-Za-z0-9_]*)'
for f in "$q/modules/bar/VolumeWidget.qml" "$q/modules/bar/Osd.qml"; do
  src=$(<"$f")
  [[ $src =~ $re ]] || {
    echo "$f does not import utils/volume.js"
    exit 1
  }
  [[ $src == *"${BASH_REMATCH[1]}.volumeGlyph("* ]] || {
    echo "$f does not call ${BASH_REMATCH[1]}.volumeGlyph"
    exit 1
  }
  # The old inline logic (medium-volume glyph U+F0580) must be gone.
  [[ $src != *$'\U000F0580'* ]] || {
    echo "$f still has its own glyph logic"
    exit 1
  }
done
LIB=$lib js_test "$here/hidden/volume.test.mjs"
