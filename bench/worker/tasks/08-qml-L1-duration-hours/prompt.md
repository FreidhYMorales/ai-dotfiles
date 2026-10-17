In my Quickshell config (`dotfiles/quickshell/.config/quickshell/`), `CUtils.formatDuration(seconds)`
in `utils/CUtils.qml` prints `m:ss`, so a 75-minute track shows as `75:00`.
Move this logic into a new JS library `utils/format.js` (a QML
`.pragma library` file) as `formatDuration(seconds)`, import it in
`CUtils.qml` and make `CUtils.formatDuration` return its result. New behavior:

- under one hour: `m:ss` as today (`0:05`, `9:59`, `59:59`)
- one hour or more: `h:mm:ss` (`1:00:00`, `1:02:05`, `10:01:01`)
- fractional seconds are floored; negative, NaN or missing input gives `0:00`

`node` can run the library if you strip the `.pragma library` line; use it to
try the cases above. Run `qmllint` on both files and make sure it reports no
errors. Change only `utils/CUtils.qml` and `utils/format.js`.
