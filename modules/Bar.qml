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
    implicitHeight: Appearance.sizes.barHeight
    color: "transparent"

    Rectangle {
        anchors.fill: parent
        anchors.topMargin: Appearance.sizes.barMargin
        anchors.leftMargin: Appearance.sizes.barMargin
        anchors.rightMargin: Appearance.sizes.barMargin
        radius: Appearance.rounding.large
        color: Colors.m3surface

        // Left: workspaces + window title
        RowLayout {
            anchors.left: parent.left
            anchors.leftMargin: 6
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width / 2 - clock.width / 2 - 12
            spacing: Appearance.sizes.spacing

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

        // Right: system status / control center button
        StatusButton {
            anchors.right: parent.right
            anchors.rightMargin: 6
            anchors.verticalCenter: parent.verticalCenter
        }
    }
}
