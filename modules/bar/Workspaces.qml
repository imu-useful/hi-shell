import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import qs.common

// Hyprland workspace indicator for the monitor this bar lives on.
Rectangle {
    id: root

    required property var screen
    readonly property HyprlandMonitor monitor: Hyprland.monitorFor(screen)

    // Hyprland 0.56+ uses Lua dispatchers; legacy "workspace N" strings
    // (and HyprlandWorkspace.activate()) are rejected.
    function focusWorkspace(target) {
        Hyprland.dispatch(`hl.dsp.focus({ workspace = ${JSON.stringify(target)} })`);
    }

    implicitWidth: row.implicitWidth + 12
    implicitHeight: Style.barHeight - 12
    radius: Style.radiusFull
    color: Colors.m3surfaceContainerHigh

    RowLayout {
        id: row
        anchors.centerIn: parent
        spacing: 4

        Repeater {
            model: Hyprland.workspaces.values.filter(ws => ws.id > 0 && ws.monitor === root.monitor)

            delegate: Rectangle {
                id: pill
                required property HyprlandWorkspace modelData
                readonly property bool isActive: root.monitor && root.monitor.activeWorkspace === modelData

                implicitHeight: 20
                implicitWidth: isActive ? 36 : 20
                radius: Style.radiusFull
                color: isActive ? Colors.m3primary : mouse.containsMouse ? Colors.m3surfaceContainerHighest : "transparent"

                Behavior on implicitWidth { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
                Behavior on color { ColorAnimation { duration: 150 } }

                Text {
                    anchors.centerIn: parent
                    text: pill.modelData.id
                    font.family: Style.fontFamily
                    font.pixelSize: 11
                    font.bold: pill.isActive
                    color: pill.isActive ? Colors.m3onPrimary : Colors.m3onSurfaceVariant
                }

                MouseArea {
                    id: mouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.focusWorkspace(pill.modelData.id)
                }
            }
        }
    }

    // Scroll to cycle workspaces on this monitor
    WheelHandler {
        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
        onWheel: event => root.focusWorkspace(event.angleDelta.y > 0 ? "m-1" : "m+1")
    }
}
