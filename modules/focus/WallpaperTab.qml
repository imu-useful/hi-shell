import QtQuick
import QtQuick.Layouts
import qs.common
import qs.common.widgets
import qs.services
import qs.modules.settings

// A wallpaper of its own for the session (it replaces cover mode while focusing), or
// the current one. Picks from the wallpaper folders, like the wallpaper selector.
ColumnLayout {
    id: root

    readonly property string chosen: Focus.profile.wallpaper

    spacing: 20

    Component.onCompleted: if (!Wallpapers.local.length && !Wallpapers.scanning) Wallpapers.scan()

    Section {
        icon: "wallpaper"
        title: Translation.tr("Wallpaper")

        SwitchRow {
            icon: "image"
            title: Translation.tr("Own wallpaper for focusing")
            subtitle: root.chosen ? root.chosen.split("/").pop() : Translation.tr("Off: the current wallpaper stays")
            checked: root.chosen !== ""
            onToggled: checked => Focus.set("wallpaper", checked ? (Wallpapers.current || Wallpapers.local[0]?.path || "") : "")
        }
    }

    Rectangle {
        Layout.fillWidth: true
        Layout.preferredHeight: width * 9 / 16
        Layout.maximumHeight: 280
        visible: root.chosen !== ""
        radius: Appearance.rounding.large
        color: Colors.m3surfaceContainer
        clip: true

        Image {
            anchors.fill: parent
            source: root.chosen ? `file://${root.chosen}` : ""
            sourceSize.width: 1000
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            opacity: status === Image.Ready ? 1 : 0
            Behavior on opacity { EffectAnim {} }
        }
    }

    Section {
        visible: root.chosen !== ""
        icon: "photo_library"
        title: Translation.tr("Pick one")

        StyledText {
            Layout.margins: 14
            visible: Wallpapers.local.length === 0
            text: Wallpapers.scanning ? Translation.tr("Making thumbnails…") : Translation.tr("No images in %1").arg(Config.options.wallpapers.directories.join(", "))
            color: Colors.m3onSurfaceVariant
        }

        Flow {
            id: grid
            Layout.fillWidth: true
            Layout.margins: 8
            spacing: 8
            readonly property real tile: (width - spacing * 3) / 4

            Repeater {
                model: Wallpapers.local

                Rectangle {
                    id: tile
                    required property var modelData
                    readonly property bool selected: modelData.path === root.chosen

                    width: grid.tile
                    height: grid.tile * 9 / 16
                    radius: Appearance.rounding.medium
                    color: Colors.m3surfaceContainerHigh
                    border.width: selected ? 3 : 0
                    border.color: Colors.m3primary

                    Image {
                        anchors.fill: parent
                        anchors.margins: tile.selected ? 3 : 0
                        source: `file://${tile.modelData.thumb}`
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                        sourceSize.width: 320
                    }
                    StateLayer {
                        onClicked: Focus.set("wallpaper", tile.modelData.path)
                    }
                }
            }
        }
    }
}
