// Hidden test for utils/volume.js (path in $LIB).
import { test } from "node:test";
import assert from "node:assert/strict";

const { loadLibrary } = await import(`${process.env.QML_SHARED}/pragma.mjs`);
const { volumeGlyph } = loadLibrary(process.env.LIB);
const MUTED = "\u{F0581}", BOOST = "\u{F075D}", HIGH = "\u{F057E}", MID = "\u{F0580}", LOW = "\u{F057F}";
const name = (g) => ({ [MUTED]: "muted", [BOOST]: "boost", [HIGH]: "high", [MID]: "mid", [LOW]: "low" })[g] ?? JSON.stringify(g);

test("volumeGlyph is defined", () => {
  assert.equal(typeof volumeGlyph, "function");
});

const cases = [
  [50, true, MUTED], [150, true, MUTED], [0, false, MUTED], [-3, false, MUTED],
  [1, false, LOW], [33, false, LOW], [34, false, MID], [66, false, MID],
  [67, false, HIGH], [100, false, HIGH], [101, false, BOOST], [150, false, BOOST],
];
for (const [volume, muted, want] of cases) {
  test(`volume ${volume} muted ${muted} -> ${name(want)}`, () => {
    assert.equal(name(volumeGlyph(volume, muted)), name(want));
  });
}
