import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Networking
import Quickshell.Bluetooth
import Quickshell.Services.Pipewire
import qs.common
import qs.common.widgets
import qs.services

// Quick toggles in two styles (Config sidebar.quickToggles.style):
// "android" = two-column pills with label and state, "classic" = round icon buttons.
// Edit mode shows every toggle: tap to add / remove, arrows to reorder.
ColumnLayout {
    id: root

    property bool editing: false

    signal openPage(string page)
    // Actions that need the screen (color picker, screenshot) close the sidebar first.
    signal closeRequested

    readonly property var options: Config.options.sidebar.quickToggles
    readonly property bool android: options.style !== "classic"
    readonly property list<string> allIds: ["wifi", "bluetooth", "darkMode", "nightLight", "dnd", "keepAwake", "mic", "gameMode", "vpn", "colorPicker", "screenshot"]
    readonly property list<string> ids: editing ? [...options.shown.filter(i => allIds.includes(i)), ...allIds.filter(i => !options.shown.includes(i))]
                                                : options.shown.filter(i => allIds.includes(i) && (toggles[i]?.available ?? false))

    readonly property var wifiDevice: Networking.devices.values.find(d => d.type === DeviceType.Wifi) ?? null
    readonly property var wifiNetwork: wifiDevice?.networks.values.find(n => n.connected) ?? null
    readonly property BluetoothAdapter bt: Bluetooth.defaultAdapter
    readonly property var btConnected: bt ? bt.devices.values.filter(d => d.connected) : []
    readonly property PwNode source: Pipewire.defaultAudioSource

    PwObjectTracker {
        objects: [root.source]
    }

    // id -> { icon, label, subtitle, active, available, toggle(), page }
    readonly property var toggles: ({
        wifi: {
            icon: !Networking.wifiEnabled ? "wifi_off" : wifiNetwork ? "wifi" : "wifi_find",
            label: Translation.tr("Wi-Fi"),
            subtitle: !Networking.wifiHardwareEnabled ? Translation.tr("Blocked") : !Networking.wifiEnabled ? Translation.tr("Off") : wifiNetwork?.name ?? Translation.tr("Not connected"),
            active: Networking.wifiEnabled,
            available: wifiDevice !== null,
            toggle: () => Networking.wifiEnabled = !Networking.wifiEnabled,
            page: "wifi"
        },
        bluetooth: {
            icon: !bt?.enabled ? "bluetooth_disabled" : btConnected.length ? "bluetooth_connected" : "bluetooth",
            label: Translation.tr("Bluetooth"),
            subtitle: !bt ? Translation.tr("Unavailable") : !bt.enabled ? Translation.tr("Off") : btConnected.length ? btConnected.map(d => d.name).join(", ") : Translation.tr("On"),
            active: bt?.enabled ?? false,
            available: bt !== null,
            toggle: () => bt.enabled = !bt.enabled,
            page: "bluetooth"
        },
        darkMode: {
            icon: Colors.dark ? "dark_mode" : "light_mode",
            label: Translation.tr("Dark mode"),
            subtitle: Theme.busy ? Translation.tr("Applying…") : Colors.dark ? Translation.tr("On") : Translation.tr("Off"),
            active: Colors.dark,
            available: true,
            toggle: () => Theme.toggleMode()
        },
        nightLight: {
            icon: "nightlight",
            label: Translation.tr("Night light"),
            subtitle: Toggles.nightLight ? `${Toggles.daemon ? Toggles.temperature : Config.options.sidebar.nightLightTemperature} K` : Translation.tr("Off"),
            active: Toggles.nightLight,
            available: true,
            toggle: () => Toggles.setNightLight(!Toggles.nightLight)
        },
        dnd: {
            icon: Notifications.dnd ? "do_not_disturb_on" : "do_not_disturb_off",
            label: Translation.tr("Do not disturb"),
            subtitle: Notifications.dnd ? Translation.tr("On") : Translation.tr("Off"),
            active: Notifications.dnd,
            available: true,
            toggle: () => Notifications.dnd = !Notifications.dnd
        },
        keepAwake: {
            icon: "coffee",
            label: Translation.tr("Keep awake"),
            subtitle: Toggles.keepAwake ? Translation.tr("Screen stays on") : Translation.tr("Off"),
            active: Toggles.keepAwake,
            available: true,
            toggle: () => Toggles.setKeepAwake(!Toggles.keepAwake)
        },
        mic: {
            icon: source?.audio?.muted ? "mic_off" : "mic",
            label: Translation.tr("Microphone"),
            subtitle: source?.audio?.muted ? Translation.tr("Muted") : Translation.tr("On"),
            active: !(source?.audio?.muted ?? true),
            available: source?.audio !== undefined && source?.audio !== null,
            toggle: () => source.audio.muted = !source.audio.muted
        },
        gameMode: {
            icon: "sports_esports",
            label: Translation.tr("Game mode"),
            subtitle: Toggles.gameMode ? Translation.tr("Effects off") : Translation.tr("Off"),
            active: Toggles.gameMode,
            available: true,
            toggle: () => Toggles.setGameMode(!Toggles.gameMode)
        },
        vpn: {
            icon: "vpn_key",
            label: Translation.tr("VPN"),
            subtitle: Toggles.vpns.find(v => v.active)?.name ?? Translation.tr("Off"),
            active: Toggles.vpnActive,
            available: Toggles.vpnAvailable,
            toggle: () => Toggles.setVpn(!Toggles.vpnActive)
        },
        colorPicker: {
            icon: "colorize",
            label: Translation.tr("Color picker"),
            subtitle: Translation.tr("Copy a color"),
            active: false,
            available: true,
            toggle: () => root.runAfterClose(["hyprpicker", "-a"])
        },
        screenshot: {
            icon: "screenshot_region",
            label: Translation.tr("Screenshot"),
            subtitle: Translation.tr("Region, text or video"),
            active: false,
            available: true,
            toggle: () => { root.closeRequested(); ShellState.captureRequest = "screenshot"; }
        }
    })

    function runAfterClose(command) {
        closeRequested();
        // Let the sidebar slide away before the tool grabs the screen.
        Quickshell.execDetached(["sh", "-c", 'sleep 0.4; exec "$@"', "sh", ...command]);
    }

    function setShown(id, shown) {
        const list = options.shown.filter(i => i !== id);
        options.shown = shown ? [...list, id] : list;
    }
    function move(id, delta) {
        const list = [...options.shown];
        const i = list.indexOf(id), j = i + delta;
        if (i < 0 || j < 0 || j >= list.length)
            return;
        [list[i], list[j]] = [list[j], list[i]];
        options.shown = list;
    }

    spacing: 10

    RowLayout {
        Layout.fillWidth: true
        visible: root.editing

        StyledText {
            Layout.fillWidth: true
            text: Translation.tr("Tap to add or remove")
            font.pixelSize: Appearance.font.size.labelMedium
            color: Colors.m3onSurfaceVariant
        }
        SegmentedButton {
            model: [{ text: Translation.tr("Android"), icon: "view_agenda" }, { text: Translation.tr("Classic"), icon: "apps" }]
            currentIndex: root.android ? 0 : 1
            onSelected: index => root.options.style = index === 0 ? "android" : "classic"
        }
    }

    GridLayout {
        Layout.fillWidth: true
        columns: root.android ? 2 : 5
        columnSpacing: 8
        rowSpacing: 8

        Repeater {
            model: root.ids

            Item {
                id: tile

                required property string modelData
                readonly property var t: root.toggles[modelData]
                readonly property bool included: root.options.shown.includes(modelData)

                Layout.fillWidth: true
                Layout.preferredWidth: 1
                implicitHeight: root.android ? 64 : 56
                opacity: root.editing && !included ? 0.45 : 1

                Rectangle {
                    id: body
                    anchors.fill: parent
                    anchors.margins: root.android ? 0 : 2
                    radius: root.android ? (tile.t.active ? Appearance.rounding.full : Appearance.rounding.extraLarge) : height / 2
                    color: tile.t.active ? Colors.m3primary : Colors.m3surfaceContainerHighest
                    border.width: root.editing ? 1 : 0
                    border.color: Colors.m3outline

                    Behavior on color { ColorAnim {} }
                    Behavior on radius { SpatialAnim { duration: Appearance.anim.normal } }

                    // Android: icon disc + label / state; the right side opens details.
                    RowLayout {
                        visible: root.android
                        anchors.fill: parent
                        anchors.leftMargin: 10
                        anchors.rightMargin: 12
                        spacing: 10

                        Rectangle {
                            implicitWidth: 40
                            implicitHeight: 40
                            radius: 20
                            color: tile.t.active ? Colors.m3onPrimary : Colors.m3surfaceContainerHigh
                            MaterialIcon {
                                anchors.centerIn: parent
                                icon: tile.t.icon
                                fill: tile.t.active ? 1 : 0
                                iconSize: 20
                                color: tile.t.active ? Colors.m3primary : Colors.m3onSurfaceVariant
                            }
                        }
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 0
                            StyledText {
                                Layout.fillWidth: true
                                text: tile.t.label
                                font.weight: Font.Medium
                                color: tile.t.active ? Colors.m3onPrimary : Colors.m3onSurface
                            }
                            StyledText {
                                Layout.fillWidth: true
                                text: tile.t.subtitle
                                font.pixelSize: Appearance.font.size.labelMedium
                                color: tile.t.active ? Qt.alpha(Colors.m3onPrimary, 0.8) : Colors.m3onSurfaceVariant
                            }
                        }
                        MaterialIcon {
                            visible: !!tile.t.page && !root.editing
                            icon: "chevron_right"
                            iconSize: 18
                            color: tile.t.active ? Colors.m3onPrimary : Colors.m3onSurfaceVariant
                        }
                    }

                    // Classic: icon only
                    MaterialIcon {
                        visible: !root.android
                        anchors.centerIn: parent
                        icon: tile.t.icon
                        fill: tile.t.active ? 1 : 0
                        iconSize: 22
                        color: tile.t.active ? Colors.m3onPrimary : Colors.m3onSurfaceVariant
                    }

                    StateLayer {
                        tint: tile.t.active ? Colors.m3onPrimary : Colors.m3onSurface
                        acceptedButtons: Qt.LeftButton | Qt.RightButton
                        onClicked: mouse => {
                            if (root.editing)
                                root.setShown(tile.modelData, !tile.included);
                            else if (tile.t.page && (mouse.button === Qt.RightButton || (root.android && mouse.x > width - 44)))
                                root.openPage(tile.t.page);
                            else
                                tile.t.toggle();
                        }
                    }
                }

                // Reorder arrows in edit mode.
                Row {
                    visible: root.editing && tile.included
                    anchors.top: parent.top
                    anchors.right: parent.right
                    anchors.margins: root.android ? 4 : -2

                    Repeater {
                        model: [{ icon: "chevron_left", delta: -1 }, { icon: "chevron_right", delta: 1 }]

                        Rectangle {
                            required property var modelData
                            width: 20
                            height: 20
                            radius: 10
                            color: Colors.m3secondaryContainer
                            MaterialIcon {
                                anchors.centerIn: parent
                                icon: modelData.icon
                                iconSize: 14
                                color: Colors.m3onSecondaryContainer
                            }
                            StateLayer {
                                onClicked: root.move(tile.modelData, modelData.delta)
                            }
                        }
                    }
                }

                StyledPopup {
                    target: tile
                    hovered: !root.android && hover.hovered
                    edge: Edges.Bottom
                    openDelay: 500
                    padding: 10
                    StyledText {
                        text: `${tile.t.label} · ${tile.t.subtitle}`
                    }
                }
                HoverHandler {
                    id: hover
                }
            }
        }
    }
}
