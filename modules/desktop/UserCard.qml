import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.common
import qs.common.widgets
import qs.common.shapes
import qs.services

// Avatar, user@host, uptime, a weather line; lock / settings / power buttons.
DesktopCard {
    id: root

    property string hostname: ""
    property bool powerMenu: false

    implicitWidth: 300
    implicitHeight: content.implicitHeight + 28

    FileView {
        path: "/etc/hostname"
        onLoaded: root.hostname = text().trim()
    }

    ColumnLayout {
        id: content
        anchors.fill: parent
        anchors.margins: 14
        spacing: 12

        RowLayout {
            spacing: 12
            ShapeImage {
                implicitWidth: 56
                implicitHeight: 56
                shape: "circle"
                source: `file://${Paths.home}/.face`
            }
            ColumnLayout {
                spacing: 0
                StyledText {
                    text: `${Quickshell.env("USER")}@${root.hostname}`
                    font.weight: Font.Medium
                }
                StyledText {
                    text: `Up · ${SystemStats.uptimeText}`
                    font.pixelSize: Appearance.font.size.labelMedium
                    color: Colors.m3onSurfaceVariant
                }
            }
        }

        RowLayout {
            visible: Weather.ready
            MaterialIcon {
                icon: Weather.icon
                iconSize: 18
            }
            StyledText {
                text: `${Weather.temperature} · ${Weather.description.toLowerCase()}`
                color: Colors.m3onSurfaceVariant
            }
        }

        RowLayout {
            spacing: 6
            M3Button {
                Layout.fillWidth: true
                tonal: true
                icon: "lock"
                text: "Lock"
                onClicked: Quickshell.execDetached(["loginctl", "lock-session"])
            }
            IconButton {
                icon: "settings"
                onClicked: ShellState.sidebarRightOpen = true
            }
            IconButton {
                icon: root.powerMenu ? "close" : "power_settings_new"
                filled: root.powerMenu
                onClicked: root.powerMenu = !root.powerMenu
            }
        }

        // Session actions, one click away from the power button (not on it).
        RowLayout {
            visible: root.powerMenu
            spacing: 6
            Repeater {
                model: [
                    { icon: "bedtime", text: "Sleep", command: ["systemctl", "suspend"] },
                    { icon: "restart_alt", text: "Reboot", command: ["systemctl", "reboot"] },
                    { icon: "power_settings_new", text: "Off", command: ["systemctl", "poweroff"] }
                ]
                Chip {
                    required property var modelData
                    icon: modelData.icon
                    text: modelData.text
                    onClicked: Quickshell.execDetached(modelData.command)
                }
            }
        }
    }
}
