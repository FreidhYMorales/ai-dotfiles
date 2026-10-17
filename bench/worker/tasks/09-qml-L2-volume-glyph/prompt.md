In my Quickshell config (`dotfiles/quickshell/.config/quickshell/`), the volume icon is picked by the same
inline ternary in two places: the bar widget `modules/bar/VolumeWidget.qml` and
the volume OSD `modules/bar/Osd.qml`. Move that choice into one function and
extend it:

1. Create `utils/volume.js`, a QML `.pragma library` JS file, with
   `volumeGlyph(volume, muted)`, where `volume` is the percentage that
   `Audio.volume` holds (an integer that can go above 100 when PipeWire boosts
   the sink). It returns:
   - the muted glyph (U+F0581) when muted, and also when the volume is 0 or less
   - a new "boost" glyph, U+F075D, when the volume is above 100
   - otherwise the same glyphs and thresholds as today: above 66 U+F057E,
     above 33 U+F0580, else U+F057F
2. Import it in both QML files and use it for the icon text, so neither file
   keeps its own copy of the glyph logic.

`node` can run the library if you strip the `.pragma library` line; use it to
try the cases. Run `qmllint` on the three files and make sure it reports no
errors. Change only those three files.
