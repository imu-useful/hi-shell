import QtQuick
import QtQuick.Layouts
import qs.common
import qs.common.widgets
import qs.services
import "Pages.js" as Pages

// The first page of Settings: wallpaper and colors, the switches changed most often,
// and a map of every other page by group.
ColumnLayout {
    id: root

    spacing: 24

    // The switches on the tiles: { icon, label, subtitle, active, toggle() }.
    readonly property var tiles: [
        {
            icon: "battery_saver",
            label: Translation.tr("Power saving"),
            subtitle: Translation.tr("Fewer effects, longer battery"),
            active: Config.options.powerSaving.enabled,
            toggle: () => PowerSaver.apply(!Config.options.powerSaving.enabled)
        },
        {
            icon: "blur_on",
            label: Translation.tr("Transparency"),
            subtitle: Translation.tr("Translucent panels and widgets"),
            active: Config.options.appearance.transparency,
            toggle: () => Config.options.appearance.transparency = !Config.options.appearance.transparency
        },
        {
            icon: Notifications.dnd ? "do_not_disturb_on" : "do_not_disturb_off",
            label: Translation.tr("Do not disturb"),
            subtitle: Translation.tr("Notifications wait in the list"),
            active: Notifications.dnd,
            toggle: () => Notifications.dnd = !Notifications.dnd
        },
        {
            icon: "nightlight",
            label: Translation.tr("Night light"),
            subtitle: Translation.tr("Warmer screen colors"),
            active: Toggles.nightLight,
            toggle: () => Toggles.setNightLight(!Toggles.nightLight)
        },
        {
            icon: "sports_esports",
            label: Translation.tr("Game mode"),
            subtitle: Translation.tr("Hyprland effects off"),
            active: Toggles.gameMode,
            toggle: () => Toggles.setGameMode(!Toggles.gameMode)
        },
        {
            icon: "science",
            label: Translation.tr("Advanced settings"),
            subtitle: Translation.tr("Show rarely needed rows"),
            active: Config.options.settingsAdvanced,
            toggle: () => Config.options.settingsAdvanced = !Config.options.settingsAdvanced
        }
    ]

    // --- Wallpaper & colors ---
    Rectangle {
        Layout.fillWidth: true
        implicitHeight: hero.implicitHeight + 32
        radius: Appearance.shape.tile
        color: Colors.m3surfaceContainer

        ColumnLayout {
            id: hero
            anchors.fill: parent
            anchors.margins: 16
            spacing: 16

            RowLayout {
                Layout.fillWidth: true
                spacing: 20

                Rectangle {
                    Layout.preferredWidth: 340
                    Layout.preferredHeight: 200
                    radius: Appearance.rounding.large
                    color: Colors.m3surfaceContainerHighest
                    clip: true

                    Image {
                        anchors.fill: parent
                        source: Wallpapers.still ? `file://${Wallpapers.still}` : ""
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                        sourceSize.width: 680
                    }
                    StateLayer {
                        onClicked: ShellState.wallpaperSelectorOpen = true
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignTop
                    spacing: 10

                    StyledText {
                        text: Translation.tr("Wallpaper & colors")
                        font.pixelSize: Appearance.font.size.titleMedium
                        font.weight: Font.Medium
                    }
                    StyledText {
                        Layout.fillWidth: true
                        text: Wallpapers.current.split("/").pop() || Translation.tr("No wallpaper")
                        color: Colors.m3onSurfaceVariant
                        elide: Text.ElideMiddle
                    }
                    RowLayout {
                        spacing: 8
                        M3Button {
                            icon: "wallpaper"
                            text: Translation.tr("Change")
                            onClicked: ShellState.wallpaperSelectorOpen = true
                        }
                        M3Button {
                            tonal: true
                            icon: "shuffle"
                            text: Translation.tr("Random")
                            onClicked: Wallpapers.local.length ? Wallpapers.random() : Wallpapers.scan()
                        }
                    }
                    Row {
                        spacing: 6
                        Repeater {
                            model: [Colors.m3primary, Colors.m3secondary, Colors.m3tertiary, Colors.m3primaryContainer, Colors.m3secondaryContainer, Colors.m3tertiaryContainer, Colors.m3surfaceContainerHighest]
                            Rectangle {
                                required property color modelData
                                width: 26
                                height: 26
                                radius: 13
                                color: modelData
                                border.width: 1
                                border.color: Colors.m3outlineVariant
                            }
                        }
                    }
                    SegmentedButton {
                        readonly property var modes: ["light", "dark", "auto"]
                        model: [
                            { text: Translation.tr("Light"), icon: "light_mode" },
                            { text: Translation.tr("Dark"), icon: "dark_mode" },
                            { text: Translation.tr("Auto"), icon: "brightness_auto" }
                        ]
                        currentIndex: modes.indexOf(Config.options.appearance.autoMode ? "auto" : Colors.mode)
                        onSelected: index => {
                            Config.options.appearance.autoMode = modes[index] === "auto";
                            if (modes[index] !== "auto")
                                Theme.setMode(modes[index]);
                        }
                    }
                    StyledText {
                        visible: Config.options.appearance.autoMode
                        text: Translation.tr("Light from sunrise to sunset")
                        font.pixelSize: Appearance.font.size.labelMedium
                        color: Colors.m3onSurfaceVariant
                    }
                }
            }

            StyledText {
                text: Translation.tr("Scheme")
                font.weight: Font.Medium
            }
            Flow {
                Layout.fillWidth: true
                spacing: 6
                Repeater {
                    model: Theme.schemes
                    Chip {
                        required property string modelData
                        text: modelData.split("-").map(w => w[0].toUpperCase() + w.slice(1)).join(" ")
                        selected: Config.options.appearance.scheme === modelData
                        onClicked: Config.options.appearance.scheme = modelData
                    }
                }
            }
        }
    }

    // --- Quick switches ---
    ColumnLayout {
        Layout.fillWidth: true
        spacing: 10

        StyledText {
            text: Translation.tr("Quick switches")
            font.pixelSize: Appearance.font.size.titleMedium
            font.weight: Font.Medium
        }

        GridLayout {
            Layout.fillWidth: true
            columns: root.width > 720 ? 3 : 2
            columnSpacing: 8
            rowSpacing: 8

            Repeater {
                model: root.tiles

                Rectangle {
                    id: tile
                    required property var modelData

                    Layout.fillWidth: true
                    implicitHeight: 72
                    radius: modelData.active ? Appearance.shape.tile : Appearance.rounding.large
                    color: modelData.active ? Colors.m3primaryContainer : Colors.m3surfaceContainer
                    Behavior on color { ColorAnim {} }
                    Behavior on radius { SpatialAnim {} }

                    readonly property color contentColor: modelData.active ? Colors.m3onPrimaryContainer : Colors.m3onSurface

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 16
                        anchors.rightMargin: 12
                        spacing: 14

                        MaterialIcon {
                            icon: tile.modelData.icon
                            fill: tile.modelData.active ? 1 : 0
                            iconSize: 24
                            color: tile.contentColor
                        }
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 0
                            StyledText {
                                Layout.fillWidth: true
                                text: tile.modelData.label
                                font.weight: Font.Medium
                                color: tile.contentColor
                                elide: Text.ElideRight
                            }
                            StyledText {
                                Layout.fillWidth: true
                                text: tile.modelData.subtitle
                                font.pixelSize: Appearance.font.size.labelMedium
                                color: tile.modelData.active ? Colors.m3onPrimaryContainer : Colors.m3onSurfaceVariant
                                elide: Text.ElideRight
                            }
                        }
                    }
                    StateLayer {
                        tint: tile.contentColor
                        onClicked: tile.modelData.toggle()
                    }
                }
            }
        }
    }

    // --- Every page, by group ---
    ColumnLayout {
        Layout.fillWidth: true
        spacing: 10

        StyledText {
            text: Translation.tr("All settings")
            font.pixelSize: Appearance.font.size.titleMedium
            font.weight: Font.Medium
        }

        GridLayout {
            Layout.fillWidth: true
            columns: root.width > 720 ? 2 : 1
            columnSpacing: 8
            rowSpacing: 8

            Repeater {
                model: Pages.groups

                Rectangle {
                    id: groupCard
                    required property var modelData

                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    implicitHeight: groupColumn.implicitHeight + 24
                    radius: Appearance.shape.tile
                    color: Colors.m3surfaceContainer

                    ColumnLayout {
                        id: groupColumn
                        anchors.fill: parent
                        anchors.margins: 12
                        spacing: 4

                        StyledText {
                            Layout.leftMargin: 6
                            Layout.bottomMargin: 2
                            text: Translation.tr(groupCard.modelData.title)
                            font.pixelSize: Appearance.font.size.labelMedium
                            font.weight: Font.Medium
                            color: Colors.m3primary
                        }

                        Repeater {
                            model: Pages.inGroup(groupCard.modelData.id)

                            ListRow {
                                required property var modelData
                                Layout.fillWidth: true
                                clickable: true
                                icon: modelData.icon
                                title: Translation.tr(modelData.title)
                                subtitle: Translation.tr(modelData.description)
                                onClicked: ShellState.settingsPage = modelData.id
                            }
                        }
                        Item { Layout.fillHeight: true }
                    }
                }
            }
        }
    }
}
