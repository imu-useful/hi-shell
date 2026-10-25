import QtQuick
import QtQuick.Layouts
import qs.common
import qs.common.widgets
import qs.services

// Wallpaper & colors at a glance.
ColumnLayout {
    spacing: 24

    Section {
        icon: "palette"
        title: Translation.tr("Wallpaper & colors")

        RowLayout {
            Layout.fillWidth: true
            Layout.margins: 10
            spacing: 16

            Rectangle {
                implicitWidth: 320
                implicitHeight: 180
                radius: Appearance.rounding.large
                color: Colors.m3surfaceContainerHighest
                clip: true
                Image {
                    anchors.fill: parent
                    source: Wallpapers.current ? `file://${Wallpapers.current}` : ""
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    sourceSize.width: 640
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 8
                StyledText {
                    Layout.fillWidth: true
                    text: Wallpapers.current.split("/").pop() || Translation.tr("No wallpaper")
                    font.weight: Font.Medium
                }
                RowLayout {
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
                // Palette preview
                Row {
                    spacing: 6
                    Repeater {
                        model: [Colors.m3primary, Colors.m3secondary, Colors.m3tertiary, Colors.m3primaryContainer, Colors.m3secondaryContainer, Colors.m3tertiaryContainer, Colors.m3surfaceContainerHighest]
                        Rectangle {
                            required property color modelData
                            width: 28
                            height: 28
                            radius: 14
                            color: modelData
                            border.width: 1
                            border.color: Colors.m3outlineVariant
                        }
                    }
                }
            }
        }

        ListRow {
            Layout.fillWidth: true
            icon: "format_paint"
            title: Translation.tr("Scheme")
        }
        Flow {
            Layout.fillWidth: true
            Layout.leftMargin: 16
            Layout.rightMargin: 16
            Layout.bottomMargin: 8
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
        ChoiceRow {
            icon: "contrast"
            title: Translation.tr("Mode")
            subtitle: Config.options.appearance.autoMode ? Translation.tr("Light from sunrise to sunset") : ""
            value: Config.options.appearance.autoMode ? "auto" : Colors.mode
            options: [
                { value: "light", text: Translation.tr("Light"), icon: "light_mode" },
                { value: "dark", text: Translation.tr("Dark"), icon: "dark_mode" },
                { value: "auto", text: Translation.tr("Auto"), icon: "brightness_auto" }
            ]
            onSelected: value => {
                Config.options.appearance.autoMode = value === "auto";
                if (value !== "auto")
                    Theme.setMode(value);
            }
        }
        SwitchRow {
            icon: "blur_on"
            title: Translation.tr("Transparency")
            subtitle: Translation.tr("Translucent panels and widgets")
            checked: Config.options.appearance.transparency
            onToggled: checked => Config.options.appearance.transparency = checked
        }
    }
}
