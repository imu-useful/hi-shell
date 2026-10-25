import QtQuick
import Quickshell.Networking
import Quickshell.Bluetooth
import Quickshell.Services.Pipewire
import qs.common
import qs.common.widgets
import qs.services

// Network / Bluetooth / volume status (+ mic muted, do not disturb).
// Click toggles the right sidebar; scroll changes the volume.
BarWidget {
    id: root

    readonly property PwNode sink: Pipewire.defaultAudioSink
    readonly property PwNode source: Pipewire.defaultAudioSource
    readonly property var wired: Networking.devices.values.find(d => d.type === DeviceType.Wired && d.connected) ?? null
    readonly property var wifiDevice: Networking.devices.values.find(d => d.type === DeviceType.Wifi) ?? null
    readonly property var wifiNetwork: wifiDevice?.networks.values.find(n => n.connected) ?? null
    readonly property BluetoothAdapter btAdapter: Bluetooth.defaultAdapter
    readonly property bool btOn: btAdapter?.enabled ?? false
    readonly property bool btConnected: btOn && btAdapter.devices.values.some(d => d.connected)

    readonly property string networkIcon: {
        if (wired)
            return "lan";
        if (!Networking.wifiEnabled)
            return "wifi_off";
        if (!wifiNetwork)
            return "signal_wifi_statusbar_not_connected";
        const s = wifiNetwork.signalStrength;
        return s > 0.75 ? "network_wifi" : s > 0.5 ? "network_wifi_3_bar" : s > 0.25 ? "network_wifi_2_bar" : "network_wifi_1_bar";
    }
    readonly property bool audioReady: sink?.audio !== null && sink?.audio !== undefined
    readonly property string volumeIcon: !audioReady || sink.audio.muted ? "volume_off" : sink.audio.volume < 0.01 ? "volume_mute" : sink.audio.volume < 0.5 ? "volume_down" : "volume_up"
    readonly property bool micMuted: source?.audio?.muted ?? false

    readonly property var icons: [
        { icon: "do_not_disturb_on", show: Notifications.dnd },
        { icon: "mic_off", show: micMuted },
        { icon: networkIcon, show: true },
        { icon: btConnected ? "bluetooth_connected" : btOn ? "bluetooth" : "bluetooth_disabled", show: btAdapter !== null },
        { icon: volumeIcon, show: true }
    ].filter(i => i.show)

    clickable: true
    scrollable: true
    active: ShellState.sidebarRightOpen
    padding: 10
    contentWidth: grid.implicitWidth
    contentHeight: grid.implicitHeight

    onClicked: ShellState.sidebarRightOpen = !ShellState.sidebarRightOpen
    onScrolled: steps => {
        if (audioReady)
            sink.audio.volume = Math.max(0, Math.min(1.5, sink.audio.volume + steps * 0.05));
    }

    PwObjectTracker {
        objects: [root.sink, root.source]
    }

    Grid {
        id: grid
        anchors.centerIn: parent
        columns: root.vertical ? 1 : root.icons.length
        spacing: 8

        Repeater {
            model: root.icons

            MaterialIcon {
                required property var modelData
                icon: modelData.icon
                iconSize: 17
                color: root.active ? Colors.m3onSecondaryContainer : Colors.m3onSurface
            }
        }
    }
}
