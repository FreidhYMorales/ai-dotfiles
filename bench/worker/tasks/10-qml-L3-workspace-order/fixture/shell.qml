import Quickshell
import QtQuick
import "modules/bar"

ShellRoot {
    Variants {
        model: Quickshell.screens

        PanelWindow {
            required property var modelData
            screen: modelData
            anchors { top: true; left: true; right: true }
            implicitHeight: 30
            color: "#1e1e2e"

            WorkspacesWidget {
                anchors.centerIn: parent
                shown: 10
            }
        }
    }
}
