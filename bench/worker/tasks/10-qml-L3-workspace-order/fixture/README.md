# bar

A small Quickshell bar: `shell.qml` puts `modules/bar/WorkspacesWidget.qml` on
every screen. The workspace logic lives in `utils/workspaces.js`, a QML
`.pragma library` file, so it can be tested without Quickshell:

    node --test tests/

Lint the QML with `qmllint modules/bar/WorkspacesWidget.qml shell.qml`.
