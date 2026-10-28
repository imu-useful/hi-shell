import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.common
import qs.common.widgets
import qs.common.shapes
import qs.services

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
                text: Translation.tr("A Material 3 Expressive desktop shell for Hyprland")
                color: Colors.m3onSurfaceVariant
            }
            StyledText {
                text: root.revision ? Translation.tr("Version %1").arg(root.revision) : ""
                font.pixelSize: Appearance.font.size.labelMedium
                color: Colors.m3outline
            }
        }
    }

    Section {
        icon: "system_update"
        title: Translation.tr("Updates")

        ChoiceRow {
            icon: "sync_alt"
            title: Translation.tr("Update from")
            subtitle: Config.options.update.channel === "release" ? Translation.tr("Release: update.sh moves to the latest tagged release") : Translation.tr("Git: update.sh pulls the latest main, the newest features")
            value: Config.options.update.channel
            options: [{ value: "release", text: Translation.tr("Release") }, { value: "git", text: "Git" }]
            onSelected: value => Config.options.update.channel = value
        }
    }

    Section {
        id: presets
        icon: "inventory_2"
        title: Translation.tr("Presets")

        property string name: ""
        property string importPath: ""

        Component.onCompleted: Presets.refresh()

        TextRow {
            icon: "save"
            title: Translation.tr("Save current setup")
            subtitle: Translation.tr("Config, wallpaper and colors; API keys, location and monitors stay out")
            placeholder: Translation.tr("Name")
            fieldWidth: 180
            onEdited: text => presets.name = text
            M3Button {
                text: Translation.tr("Save")
                enabled: !Presets.busy
                onClicked: Presets.exportPreset(presets.name)
            }
        }
        Repeater {
            model: Presets.list
            ListRow {
                required property var modelData
                Layout.fillWidth: true
                icon: "style"
                title: modelData.name
                subtitle: [modelData.created.replace("T", " ").slice(0, 16), modelData.wallpaper].filter(s => s).join(" · ")
                M3Button {
                    tonal: true
                    text: Translation.tr("Apply")
                    enabled: !Presets.busy
                    onClicked: Presets.importPreset(modelData.path)
                }
                IconButton {
                    icon: "delete"
                    tooltip: Translation.tr("Delete")
                    onClicked: Presets.remove(modelData.path)
                }
            }
        }
        TextRow {
            icon: "upload_file"
            title: Translation.tr("Apply from a file")
            subtitle: Presets.error || Translation.tr("A .tar.gz preset someone shared")
            placeholder: "~/Downloads/preset.tar.gz"
            fieldWidth: 220
            onEdited: text => presets.importPath = text.trim()
            M3Button {
                tonal: true
                text: Translation.tr("Apply")
                enabled: presets.importPath !== "" && !Presets.busy
                onClicked: Presets.importPreset(presets.importPath)
            }
        }
        ListRow {
            Layout.fillWidth: true
            icon: "folder_open"
            title: Translation.tr("Open presets folder")
            subtitle: Presets.dir.replace(Paths.home, "~")
            clickable: true
            onClicked: {
                Quickshell.execDetached(["mkdir", "-p", Presets.dir]);
                Qt.openUrlExternally(`file://${Presets.dir}`);
            }
        }
    }

    Section {
        icon: "info"
        title: Translation.tr("Components")

        ListRow { Layout.fillWidth: true; icon: "deployed_code"; title: "Quickshell"; subtitle: root.quickshell }
        ListRow { Layout.fillWidth: true; icon: "palette"; title: "matugen"; subtitle: Translation.tr("Material 3 colors from the wallpaper") }
        ListRow { Layout.fillWidth: true; icon: "settings"; title: Translation.tr("Config"); subtitle: Config.path.replace(Paths.home, "~") }
    }

    Section {
        icon: "link"
        title: Translation.tr("Links")

        ListRow {
            Layout.fillWidth: true
            icon: "code"
            title: Translation.tr("Source")
            subtitle: "github.com/imu-useful/hi-shell"
            clickable: true
            onClicked: Qt.openUrlExternally("https://github.com/imu-useful/hi-shell")
        }
        ListRow {
            Layout.fillWidth: true
            icon: "favorite"
            title: Translation.tr("Inspired by end4-pC and illogical-impulse")
            subtitle: "github.com/pctrade/end4-pC · github.com/end-4/dots-hyprland"
            clickable: true
            onClicked: Qt.openUrlExternally("https://github.com/pctrade/end4-pC")
        }
    }
}
