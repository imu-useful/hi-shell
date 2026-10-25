import QtQuick
import QtQuick.Layouts
import Quickshell.Networking
import Quickshell.Bluetooth
import Quickshell.Services.Pipewire
import qs.common

// Right side of the bar: CPU/RAM and network/bluetooth/volume status.
// Clicking toggles the control center.
Rectangle {
    id: root

    readonly property PwNode sink: Pipewire.defaultAudioSink
    readonly property bool btEnabled: Bluetooth.defaultAdapter !== null && Bluetooth.defaultAdapter.enabled

    implicitWidth: row.implicitWidth + 24
    implicitHeight: Style.barHeight - 12
    radius: Style.radiusFull
    color: ShellState.controlCenterOpen ? Colors.m3secondaryContainer : mouse.containsMouse ? Colors.m3surfaceContainerHighest : Colors.m3surfaceContainerHigh

    Behavior on color { ColorAnimation { duration: 150 } }

    PwObjectTracker {
        objects: [root.sink]
    }

    component Icon: Text {
        font.family: Style.iconFont
        font.pixelSize: 17
        color: Colors.m3onSurfaceVariant
    }

    component Label: Text {
        font.family: Style.fontFamily
        font.pixelSize: 12
        color: Colors.m3onSurfaceVariant
    }

    RowLayout {
        id: row
        anchors.centerIn: parent
        spacing: 6

        Icon { text: "memory" }
        Label { text: Math.round(SystemStats.cpuUsage * 100) + "%" }
        Icon { text: "memory_alt"; Layout.leftMargin: 4 }
        Label { text: Math.round(SystemStats.memUsage * 100) + "%" }

        Rectangle {
            Layout.leftMargin: 4
            Layout.rightMargin: 4
            implicitWidth: 1
            implicitHeight: 14
            color: Colors.m3outlineVariant
        }

        Icon { text: Networking.wifiEnabled ? "wifi" : "wifi_off" }
        Icon { text: root.btEnabled ? "bluetooth" : "bluetooth_disabled" }
        Icon {
            readonly property bool ready: root.sink !== null && root.sink.audio !== null
            text: !ready || root.sink.audio.muted ? "volume_off" : root.sink.audio.volume < 0.5 ? "volume_down" : "volume_up"
        }
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: ShellState.controlCenterOpen = !ShellState.controlCenterOpen
    }
}
