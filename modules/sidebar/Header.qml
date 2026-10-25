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
RowLayout {
    id: root

    property bool editing: false
    property bool powerMenu: false
    property string hostname: ""

    signal closeRequested

    spacing: 12

    FileView {
        path: "/etc/hostname"
        onLoaded: root.hostname = text().trim()
    }

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
        }
        StyledText {
            text: Translation.tr("Up %1").arg(SystemStats.uptimeText)
            font.pixelSize: Appearance.font.size.labelMedium
            color: Colors.m3onSurfaceVariant
        }
    }

    // Power actions replace the regular buttons while open.
    Repeater {
        model: root.powerMenu ? [
            { icon: "lock", run: () => Session.lock() },
            { icon: "bedtime", run: () => Session.suspend() },
            { icon: "logout", run: () => Session.logout() },
            { icon: "restart_alt", run: () => Session.reboot() },
            { icon: "power_settings_new", run: () => Session.poweroff() }
        ] : [
            { icon: "edit", active: root.editing, run: () => root.editing = !root.editing },
            { icon: "refresh", run: () => Quickshell.reload(false) },
            { icon: "settings", run: () => { root.closeRequested(); ShellState.settingsOpen = true; } }
        ]

        IconButton {
            required property var modelData
            implicitWidth: 36
            implicitHeight: 36
            icon: modelData.icon
            filled: modelData.active ?? false
            onClicked: {
                root.powerMenu = false;
                modelData.run();
            }
        }
    }

    IconButton {
        implicitWidth: 36
        implicitHeight: 36
        icon: root.powerMenu ? "close" : "power_settings_new"
        filled: root.powerMenu
        onClicked: root.powerMenu = !root.powerMenu
    }
}
