import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import Quickshell.Wayland
import Quickshell.Networking
import Quickshell.Bluetooth
import qs.common
import qs.modules.controlcenter

// Slide-out quick settings panel on the right edge.
// Toggle: bar status button, Hyprland global shortcut "hi-shell:controlCenterToggle",
//         or `qs -c hi-shell ipc call controlcenter toggle`.
Scope {
    id: root

    readonly property bool open: ShellState.controlCenterOpen

    readonly property var wifiDevice: Networking.devices.values.find(d => d.type === DeviceType.Wifi) ?? null
    readonly property var wifiNetwork: wifiDevice ? wifiDevice.networks.values.find(n => n.connected) ?? null : null

    readonly property BluetoothAdapter btAdapter: Bluetooth.defaultAdapter
    readonly property bool btEnabled: btAdapter !== null && btAdapter.enabled
    readonly property var btConnected: btAdapter ? btAdapter.devices.values.filter(d => d.connected) : []

    function setOpen(value) {
        ShellState.controlCenterOpen = value;
    }

    GlobalShortcut {
        appid: "hi-shell"
        name: "controlCenterToggle"
        description: "Toggle the hi-shell control center"
        onPressed: root.setOpen(!root.open)
    }

    IpcHandler {
        target: "controlcenter"

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

    PanelWindow {
        id: window

        screen: Quickshell.screens.find(s => s.name === Hyprland.focusedMonitor?.name) ?? Quickshell.screens[0]
        visible: root.open || panel.x < window.width

        anchors.top: true
        anchors.right: true
        // Sit below the bars (respect their exclusive zones) without reserving space.
        exclusiveZone: 0
        margins.top: Style.barMargin
        implicitWidth: 400 + Style.barMargin
        implicitHeight: panel.implicitHeight
        color: "transparent"

        WlrLayershell.namespace: "hi-shell-controlcenter"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: root.open ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

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
            id: panel

            x: root.open ? 0 : window.width
            width: 400
            implicitHeight: column.implicitHeight + 32
            radius: 28
            color: Qt.alpha(Colors.m3surfaceContainer, 0.92)
            border.width: 1
            border.color: Colors.m3outlineVariant

            Behavior on x { NumberAnimation { duration: 260; easing.type: Easing.OutCubic } }

            ColumnLayout {
                id: column
                anchors.fill: parent
                anchors.margins: 16
                spacing: 16

                Text {
                    Layout.leftMargin: 4
                    text: "Control Center"
                    font.family: Style.fontFamily
                    font.pixelSize: 18
                    font.weight: Font.Medium
                    color: Colors.m3onSurface
                }

                GridLayout {
                    Layout.fillWidth: true
                    columns: 2
                    columnSpacing: 10
                    rowSpacing: 10

                    ToggleTile {
                        Layout.fillWidth: true
                        Layout.preferredWidth: 1
                        icon: Networking.wifiEnabled ? "wifi" : "wifi_off"
                        label: "Wi-Fi"
                        subtitle: !Networking.wifiHardwareEnabled ? "Blocked" : !Networking.wifiEnabled ? "Off" : root.wifiNetwork ? root.wifiNetwork.name : "Not connected"
                        active: Networking.wifiEnabled
                        enabled: Networking.wifiHardwareEnabled
                        onClicked: Networking.wifiEnabled = !Networking.wifiEnabled
                    }

                    ToggleTile {
                        Layout.fillWidth: true
                        Layout.preferredWidth: 1
                        icon: !root.btEnabled ? "bluetooth_disabled" : root.btConnected.length > 0 ? "bluetooth_connected" : "bluetooth"
                        label: "Bluetooth"
                        subtitle: !root.btAdapter ? "Unavailable" : !root.btEnabled ? "Off" : root.btConnected.length > 0 ? root.btConnected.map(d => d.name).join(", ") : "On"
                        active: root.btEnabled
                        enabled: root.btAdapter !== null
                        onClicked: root.btAdapter.enabled = !root.btAdapter.enabled
                    }

                    ToggleTile {
                        Layout.fillWidth: true
                        Layout.preferredWidth: 1
                        icon: Colors.dark ? "dark_mode" : "light_mode"
                        label: "Dark mode"
                        subtitle: Theme.busy ? "Applying…" : Colors.dark ? "On" : "Off"
                        active: Colors.dark
                        onClicked: Theme.toggleMode()
                    }
                }

                VolumeControl {
                    Layout.fillWidth: true
                }

                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: 1
                    color: Colors.m3outlineVariant
                }

                StatBar {
                    Layout.fillWidth: true
                    icon: "memory"
                    label: "CPU"
                    detail: Math.round(SystemStats.cpuUsage * 100) + "%"
                    value: SystemStats.cpuUsage
                }

                StatBar {
                    Layout.fillWidth: true
                    icon: "memory_alt"
                    label: "RAM"
                    detail: `${SystemStats.memUsedGiB.toFixed(1)} / ${SystemStats.memTotalGiB.toFixed(1)} GiB`
                    value: SystemStats.memUsage
                }
            }
        }
    }
}
