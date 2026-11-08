import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.common
import qs.common.widgets
import qs.services

// A fetch-style block: the distribution's logo and a few facts about the system.
Tile {
    id: root

    property string os: ""
    property string kernel: ""
    property string host: ""
    readonly property string wm: Quickshell.env("XDG_CURRENT_DESKTOP") || "Hyprland"

    radius: Appearance.rounding.medium
    implicitHeight: layout.implicitHeight + Appearance.space.xl * 2

    FileView {
        path: "/etc/os-release"
        printErrors: false
        onLoaded: {
            const line = text().split("\n").find(l => l.startsWith("PRETTY_NAME="));
            root.os = line ? line.slice(12).replace(/"/g, "").trim() : "";
        }
    }
    FileView {
        path: "/proc/sys/kernel/osrelease"
        onLoaded: root.kernel = text().trim()
    }
    FileView {
        path: "/etc/hostname"
        onLoaded: root.host = text().trim()
    }

    RowLayout {
        id: layout
        anchors.centerIn: parent
        width: parent.width - Appearance.space.xl * 2
        spacing: Appearance.space.lg

        DistroLogo {
            Layout.preferredWidth: 56
            Layout.preferredHeight: 56
            logo: Distro.logo
            visible: !failed
            tint: Colors.m3primary
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 2

            component Line: RowLayout {
                property string label
                property string value
                Layout.fillWidth: true
                visible: value !== ""
                spacing: Appearance.space.sm
                StyledText {
                    text: parent.label
                    color: Colors.m3primary
                    font.family: Appearance.font.mono
                    font.pixelSize: Appearance.font.size.labelMedium
                }
                StyledText {
                    Layout.fillWidth: true
                    text: parent.value
                    font.family: Appearance.font.mono
                    font.pixelSize: Appearance.font.size.labelMedium
                }
            }

            Line { label: "user"; value: `${Quickshell.env("USER")}@${root.host}` }
            Line { label: "os"; value: root.os }
            Line { label: "wm"; value: root.wm }
            Line { label: "kernel"; value: root.kernel }
            Line { label: "up"; value: SystemStats.uptimeText }
        }
    }
}
