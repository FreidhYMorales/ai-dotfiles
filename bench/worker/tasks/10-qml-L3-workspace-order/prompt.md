Bug report for this Quickshell bar (see README.md):

I set the bar to show 10 workspaces (`shown: 10` in `shell.qml`). Now the
workspace 10 dot sits right after workspace 1, before 2, and when I scroll
down on the bar from workspace 1 it jumps to workspace 10 instead of 2. The
same happens with any workspace numbered 10 or more that I open, e.g. 12.
With fewer than 10 workspaces everything is fine.

Find the cause and fix it, without changing how anything else behaves. Add a
test that reproduces the problem to `tests/workspaces.test.mjs`, then run
`node --test tests/` and make sure every test passes, and make sure `qmllint`
reports no errors for the QML you touch. Change only `utils/workspaces.js`,
`modules/bar/WorkspacesWidget.qml` or `tests/workspaces.test.mjs`.
