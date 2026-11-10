import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import qs.common
import qs.common.widgets
import qs.common.shapes
import qs.services

// Avatar, user@host and uptime, plus edit toggles / reload / settings / power.
// The power actions get a row of their own under the header: in the header's row they'd make the
// panel wider than the screen's edge allows.
ColumnLayout {
    id: root

    property bool editing: false
    property bool powerMenu: false
    property string hostname: ""

    signal closeRequested

    spacing: 10

    FileView {
        path: "/etc/hostname"
        onLoaded: root.hostname = text().trim()
    }

    component HeaderButton: IconButton {
        implicitWidth: 36
        implicitHeight: 36
    }

    RowLayout {
        Layout.fillWidth: true
        spacing: 12

        ShapeImage {
            implicitWidth: 52
            implicitHeight: 52
            shape: "cookie9"
            source: `file://${Paths.home}/.face`

            MaterialShape {
                anchors.fill: parent
                visible: parent.status !== Image.Ready
                shape: "cookie9"
                color: Colors.m3primaryContainer
                MaterialIcon {
                    anchors.centerIn: parent
                    icon: "person"
                    fill: 1
                    color: Colors.m3onPrimaryContainer
                }
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 0
            StyledText {
                Layout.fillWidth: true
                text: `${Quickshell.env("USER")}${root.hostname ? "@" + root.hostname : ""}`
                font.pixelSize: Appearance.font.size.titleMedium
                font.weight: Font.Medium
                elide: Text.ElideRight
            }
            StyledText {
                text: Translation.tr("Up %1").arg(SystemStats.uptimeText)
                font.pixelSize: Appearance.font.size.labelMedium
                color: Colors.m3onSurfaceVariant
            }
        }

        Repeater {
            model: root.powerMenu ? [] : [
                { icon: "edit", active: root.editing, run: () => root.editing = !root.editing },
                { icon: "refresh", run: () => Quickshell.reload(false) },
                { icon: "settings", run: () => { root.closeRequested(); ShellState.settingsOpen = true; } }
            ]

            HeaderButton {
                required property var modelData
                icon: modelData.icon
                filled: modelData.active ?? false
                onClicked: modelData.run()
            }
        }

        HeaderButton {
            icon: root.powerMenu ? "close" : "power_settings_new"
            filled: root.powerMenu
            onClicked: root.powerMenu = !root.powerMenu
        }
    }

    // Power actions, in a row under the header while it's open.
    RowLayout {
        Layout.fillWidth: true
        visible: root.powerMenu
        spacing: 8

        Item {
            Layout.fillWidth: true
        }
        Repeater {
            model: [
                { icon: "lock", run: () => Session.lock() },
                { icon: "bedtime", run: () => Session.suspend() },
                { icon: "logout", run: () => Session.logout() },
                { icon: "restart_alt", run: () => Session.reboot() },
                { icon: "power_settings_new", run: () => Session.poweroff() }
            ]

            HeaderButton {
                required property var modelData
                icon: modelData.icon
                onClicked: {
                    root.powerMenu = false;
                    modelData.run();
                }
            }
        }
    }
}
