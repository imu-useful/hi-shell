import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.common
import qs.modules.bar

// Top bar, one instance per screen (instantiated via Variants in shell.qml).
PanelWindow {
    id: root

    required property var modelData
    screen: modelData

    anchors {
        top: true
        left: true
        right: true
    }
    implicitHeight: Style.barHeight
    color: "transparent"

    Rectangle {
        anchors.fill: parent
        anchors.topMargin: Style.barMargin
        anchors.leftMargin: Style.barMargin
        anchors.rightMargin: Style.barMargin
        radius: Style.radiusLarge
        color: Colors.m3surface

        // Left: workspaces + window title
        RowLayout {
            anchors.left: parent.left
            anchors.leftMargin: 6
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width / 2 - clock.width / 2 - 12
            spacing: Style.spacing

            Workspaces {
                screen: root.screen
            }

            WindowTitle {
                Layout.fillWidth: true
            }
        }

        // Center: clock
        Clock {
            id: clock
            anchors.centerIn: parent
        }
    }
}
