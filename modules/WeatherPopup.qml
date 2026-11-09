import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import Quickshell.Wayland
import qs.common
import qs.common.widgets
import qs.services

// Weather details under the bar: the current conditions, the next 24 hours and the 7 days.
// Toggle: click the weather in the bar, or `qs -c hi-shell ipc call weatherDetails toggle`.
Scope {
    id: root

    readonly property bool open: ShellState.weatherOpen

    function setOpen(value) {
        ShellState.weatherOpen = value;
    }

    // The 7 days' range, for the bars of the daily temperatures.
    readonly property real weekMin: Weather.daily.length ? Math.min(...Weather.daily.map(d => d.min)) : 0
    readonly property real weekMax: Weather.daily.length ? Math.max(...Weather.daily.map(d => d.max)) : 1

    function hour(iso) {
        return iso.slice(11, 16);
    }
    function weekday(date) {
        return new Date(date + "T12:00").toLocaleDateString(Translation.locale, "ddd");
    }

    IpcHandler {
        target: "weatherDetails"

        function toggle(): void {
            root.setOpen(!root.open);
        }
        function open(): void {
            root.setOpen(true);
        }
        function close(): void {
            root.setOpen(false);
        }
    }

    component Stat: RowLayout {
        property string icon
        property string text
        Layout.fillWidth: true
        Layout.preferredWidth: 1
        spacing: 6
        MaterialIcon {
            icon: parent.icon
            iconSize: 16
        }
        StyledText {
            Layout.fillWidth: true
            text: parent.text
            font.pixelSize: Appearance.font.size.labelMedium
            color: Colors.m3onSurfaceVariant
        }
    }

    PanelLoader {
        id: loader
        shown: root.open

        PanelWindow {
            id: window

            screen: Quickshell.screens.find(s => s.name === Hyprland.focusedMonitor?.name) ?? Quickshell.screens[0]

            // Under the bar, from the bottom when the bar is at the bottom.
            readonly property bool atBottom: Config.options.bar.position === "bottom"
            anchors.top: !atBottom
            anchors.bottom: atBottom
            exclusiveZone: 0
            margins.top: Appearance.sizes.barMargin
            margins.bottom: Appearance.sizes.barMargin
            implicitWidth: 420
            implicitHeight: card.implicitHeight
            color: "transparent"

            WlrLayershell.namespace: "hi-shell-weather"
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.keyboardFocus: root.open ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None

            HyprlandFocusGrab {
                windows: [window]
                active: root.open
                onCleared: root.setOpen(false)
            }

            Shortcut {
                sequence: "Escape"
                onActivated: root.setOpen(false)
            }

            Rectangle {
                id: card

                width: parent.width
                implicitHeight: column.implicitHeight + 32
                radius: Appearance.shape.panel
                color: Appearance.translucent(Colors.m3surfaceContainer)
                border.width: Appearance.edge
                border.color: Appearance.edgeColor

                GlassSheen {}

                opacity: loader.revealed ? 1 : 0
                scale: loader.revealed ? 1 : 0.85
                transformOrigin: window.atBottom ? Item.Bottom : Item.Top
                Behavior on opacity { EffectAnim {} }
                Behavior on scale { SpringAnim {} }

                ColumnLayout {
                    id: column
                    anchors.fill: parent
                    anchors.margins: 16
                    spacing: 14

                    // Header: temperature, condition and city; refresh.
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 12

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 0
                            StyledText {
                                text: Weather.temperature
                                font.pixelSize: Appearance.font.size.headlineLarge
                                font.weight: Font.Medium
                            }
                            StyledText {
                                text: Weather.description
                            }
                            StyledText {
                                text: Weather.city || Translation.tr("Unknown location")
                                font.pixelSize: Appearance.font.size.labelMedium
                                color: Colors.m3onSurfaceVariant
                            }
                        }
                        IconButton {
                            icon: "refresh"
                            tooltip: Translation.tr("Refresh")
                            onClicked: Weather.refresh()
                        }
                        MaterialIcon {
                            icon: Weather.icon
                            iconSize: 48
                            fill: 1
                            color: Colors.m3primary
                        }
                    }

                    StyledText {
                        Layout.fillWidth: true
                        visible: Weather.error !== ""
                        text: Weather.error
                        color: Colors.m3error
                        wrapMode: Text.Wrap
                    }

                    GridLayout {
                        Layout.fillWidth: true
                        visible: Weather.ready
                        columns: 2
                        rowSpacing: 6
                        columnSpacing: 16

                        Stat {
                            icon: "thermostat"
                            text: Weather.ready ? Translation.tr("Feels like %1").arg(Math.round(Weather.current.feelsLike) + Weather.tempUnit) : ""
                        }
                        Stat {
                            icon: "humidity_percentage"
                            text: Weather.ready ? `${Weather.current.humidity}%` : ""
                        }
                        Stat {
                            icon: "air"
                            text: Weather.ready ? `${Weather.current.wind.toFixed(1)} ${Weather.windUnit}` : ""
                        }
                        Stat {
                            icon: "visibility"
                            text: Weather.ready ? Translation.tr("%1 km").arg((Weather.current.visibility / 1000).toFixed(1)) : ""
                        }
                        Stat {
                            icon: "cloud"
                            text: Weather.ready ? Translation.tr("Clouds %1%").arg(Weather.current.cloudCover) : ""
                        }
                        Stat {
                            icon: "wb_twilight"
                            text: Weather.daily.length ? `${root.hour(Weather.daily[0].sunrise)} · ${root.hour(Weather.daily[0].sunset)}` : ""
                        }
                    }

                    // The next 24 hours, scrolled sideways.
                    StyledText {
                        text: Translation.tr("Next 24 hours")
                        font.pixelSize: Appearance.font.size.titleMedium
                        font.weight: Font.Medium
                        visible: Weather.hourly.length > 0
                    }
                    ListView {
                        id: hours
                        Layout.fillWidth: true
                        Layout.preferredHeight: 104
                        visible: Weather.hourly.length > 0
                        orientation: ListView.Horizontal
                        spacing: 4
                        clip: true
                        boundsBehavior: Flickable.StopAtBounds
                        model: Weather.hourly

                        delegate: ColumnLayout {
                            required property var modelData
                            width: 52
                            height: hours.height
                            spacing: 2

                            StyledText {
                                Layout.alignment: Qt.AlignHCenter
                                text: root.hour(modelData.time)
                                font.pixelSize: Appearance.font.size.labelSmall
                                color: Colors.m3onSurfaceVariant
                            }
                            MaterialIcon {
                                Layout.alignment: Qt.AlignHCenter
                                icon: Weather.iconFor(modelData.code, modelData.isDay)
                                iconSize: 22
                                color: Colors.m3onSurface
                            }
                            StyledText {
                                Layout.alignment: Qt.AlignHCenter
                                text: `${Math.round(modelData.temp)}°`
                                font.pixelSize: Appearance.font.size.labelMedium
                            }
                            StyledText {
                                Layout.alignment: Qt.AlignHCenter
                                visible: modelData.precipitation > 0
                                text: `${modelData.precipitation}%`
                                font.pixelSize: Appearance.font.size.labelSmall
                                color: Colors.m3primary
                            }
                        }
                    }

                    // The 7 days: rain chance, and the day's range on the week's scale.
                    StyledText {
                        text: Translation.tr("7 days")
                        font.pixelSize: Appearance.font.size.titleMedium
                        font.weight: Font.Medium
                        visible: Weather.daily.length > 0
                    }
                    Repeater {
                        model: Weather.daily

                        RowLayout {
                            required property var modelData
                            required property int index
                            Layout.fillWidth: true
                            spacing: 10

                            StyledText {
                                Layout.preferredWidth: 44
                                text: index === 0 ? Translation.tr("Today") : root.weekday(modelData.date)
                            }
                            MaterialIcon {
                                icon: Weather.iconFor(modelData.code, true)
                                iconSize: 20
                                color: Colors.m3onSurface
                            }
                            StyledText {
                                Layout.preferredWidth: 40
                                text: modelData.precipitation > 0 ? `${modelData.precipitation}%` : ""
                                font.pixelSize: Appearance.font.size.labelMedium
                                color: Colors.m3primary
                            }
                            StyledText {
                                Layout.preferredWidth: 36
                                horizontalAlignment: Text.AlignRight
                                text: `${Math.round(modelData.min)}°`
                                color: Colors.m3onSurfaceVariant
                            }
                            // The day's range, placed on the week's range.
                            Item {
                                Layout.fillWidth: true
                                implicitHeight: 6
                                Rectangle {
                                    anchors.fill: parent
                                    radius: 3
                                    color: Colors.m3surfaceContainerHighest
                                }
                                Rectangle {
                                    readonly property real span: Math.max(0.001, root.weekMax - root.weekMin)
                                    x: parent.width * (modelData.min - root.weekMin) / span
                                    width: Math.max(6, parent.width * (modelData.max - modelData.min) / span)
                                    height: parent.height
                                    radius: 3
                                    color: Colors.m3primary
                                }
                            }
                            StyledText {
                                Layout.preferredWidth: 36
                                text: `${Math.round(modelData.max)}°`
                            }
                        }
                    }
                }
            }
        }
    }
}
