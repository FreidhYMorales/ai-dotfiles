import QtQuick
import Quickshell.Hyprland
import "../../utils/workspaces.js" as Ws

// Workspace dots: click to switch, scroll to move to the next/previous one.
Row {
    id: root

    // Workspaces 1..shown are always listed, even when empty.
    property int shown: 5
    readonly property int activeId: Hyprland.focusedWorkspace ? Hyprland.focusedWorkspace.id : 1
    readonly property var items: Ws.buildWorkspaces(
        Hyprland.workspaces.values.map(w => ({ id: w.id, windows: w.toplevels.values.length })),
        activeId, shown)

    spacing: 4

    Repeater {
        model: root.items

        delegate: Rectangle {
            id: dot
            required property var modelData
            width: modelData.active ? 22 : 10
            height: 10
            radius: 5
            color: modelData.active ? "#cba6f7" : modelData.occupied ? "#a6adc8" : "#45475a"

            Text {
                anchors.centerIn: parent
                visible: dot.modelData.active
                text: Ws.workspaceLabel(dot.modelData.id)
                font.pixelSize: 8
                color: "#1e1e2e"
            }

            MouseArea {
                anchors.fill: parent
                onClicked: Hyprland.dispatch("workspace " + dot.modelData.id)
            }
        }
    }

    WheelHandler {
        onWheel: event => {
            const step = event.angleDelta.y < 0 ? 1 : -1
            Hyprland.dispatch("workspace " + Ws.nextWorkspace(root.items, root.activeId, step))
        }
    }
}
