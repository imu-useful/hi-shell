import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.common
import qs.common.widgets
import qs.common.shapes

// Version, components, links.
ColumnLayout {
    id: root

    property string revision: ""
    property string quickshell: ""

    spacing: 24

    Process {
        running: true
        command: ["sh", "-c", 'git -C "$1" log -1 --format="%h · %cs" 2>/dev/null; qs --version 2>/dev/null | head -1', "sh", Quickshell.shellDir]
        stdout: StdioCollector {
            onStreamFinished: {
                const l = text.trim().split("\n");
                root.revision = l[0] ?? "";
                root.quickshell = l[1] ?? "";
            }
        }
    }

    RowLayout {
        spacing: 20
        Item {
            implicitWidth: 96
            implicitHeight: 96
            MaterialShape {
                anchors.fill: parent
                shape: "sunny"
                color: Colors.m3primaryContainer
            }
            MaterialIcon {
                anchors.centerIn: parent
                icon: "auto_awesome"
                fill: 1
                iconSize: 44
                color: Colors.m3onPrimaryContainer
            }
        }
        ColumnLayout {
            spacing: 2
            StyledText {
                text: "hi-shell"
                font.pixelSize: Appearance.font.size.headlineMedium
                font.weight: Font.Medium
            }
            StyledText {
                text: "A Material 3 Expressive desktop shell for Hyprland"
                color: Colors.m3onSurfaceVariant
            }
            StyledText {
                text: root.revision ? `Version ${root.revision}` : ""
                font.pixelSize: Appearance.font.size.labelMedium
                color: Colors.m3outline
            }
        }
    }

    Section {
        icon: "info"
        title: "Components"

        ListRow { Layout.fillWidth: true; icon: "deployed_code"; title: "Quickshell"; subtitle: root.quickshell }
        ListRow { Layout.fillWidth: true; icon: "palette"; title: "matugen"; subtitle: "Material 3 colors from the wallpaper" }
        ListRow { Layout.fillWidth: true; icon: "settings"; title: "Config"; subtitle: Config.path.replace(Paths.home, "~") }
    }

    Section {
        icon: "link"
        title: "Links"

        ListRow {
            Layout.fillWidth: true
            icon: "code"
            title: "Source"
            subtitle: "github.com/imu-useful/hi-shell"
            clickable: true
            onClicked: Qt.openUrlExternally("https://github.com/imu-useful/hi-shell")
        }
        ListRow {
            Layout.fillWidth: true
            icon: "favorite"
            title: "Inspired by end4-pC and illogical-impulse"
            subtitle: "github.com/pctrade/end4-pC · github.com/end-4/dots-hyprland"
            clickable: true
            onClicked: Qt.openUrlExternally("https://github.com/pctrade/end4-pC")
        }
    }
}
