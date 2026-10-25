import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Bluetooth
import qs.common
import qs.common.widgets

// Bluetooth devices: paired ones first, then devices found while the page is
// open (it scans). Tap to connect / disconnect / pair; forget paired ones.
StyledFlickable {
    id: root

    readonly property BluetoothAdapter adapter: Bluetooth.defaultAdapter
    readonly property var devices: (adapter?.devices.values ?? []).filter(d => d.paired || d.name)
        .sort((a, b) => (b.connected - a.connected) || (b.paired - a.paired) || a.name.localeCompare(b.name))
    property var expanded: null

    contentHeight: column.implicitHeight

    Component.onCompleted: if (adapter?.enabled) adapter.discovering = true
    Component.onDestruction: if (adapter) adapter.discovering = false

    function deviceIcon(d) {
        const icon = d.icon ?? "";
        if (icon.includes("audio-headset") || icon.includes("headphone")) return "headphones";
        if (icon.includes("audio")) return "speaker";
        if (icon.includes("phone")) return "smartphone";
        if (icon.includes("mouse")) return "mouse";
        if (icon.includes("keyboard")) return "keyboard";
        if (icon.includes("gaming") || icon.includes("joystick")) return "sports_esports";
        if (icon.includes("computer")) return "computer";
        return "bluetooth";
    }

    ColumnLayout {
        id: column
        width: root.width
        spacing: 2

        ListRow {
            Layout.fillWidth: true
            icon: "bluetooth"
            title: Translation.tr("Bluetooth")
            subtitle: !root.adapter ? Translation.tr("No adapter") : root.adapter.discovering ? Translation.tr("Searching for devices…") : root.adapter.name
            M3Switch {
                checked: root.adapter?.enabled ?? false
                enabled: root.adapter !== null
                onToggled: checked => {
                    root.adapter.enabled = checked;
                    if (checked)
                        root.adapter.discovering = true;
                }
            }
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.topMargin: 4
            Layout.bottomMargin: 4
            implicitHeight: 1
            color: Colors.m3outlineVariant
        }

        Repeater {
            model: root.adapter?.enabled ? root.devices : []

            ColumnLayout {
                id: entry

                required property BluetoothDevice modelData
                readonly property bool open: root.expanded === modelData

                Layout.fillWidth: true
                spacing: 0

                ListRow {
                    Layout.fillWidth: true
                    icon: root.deviceIcon(entry.modelData)
                    title: entry.modelData.name || entry.modelData.address
                    subtitle: entry.modelData.pairing ? Translation.tr("Pairing…")
                        : entry.modelData.state === BluetoothDeviceState.Connecting ? Translation.tr("Connecting…")
                        : entry.modelData.connected ? Translation.tr("Connected") + (entry.modelData.batteryAvailable ? " · " + Math.round(entry.modelData.battery * 100) + "%" : "")
                        : entry.modelData.paired ? Translation.tr("Paired") : Translation.tr("Available")
                    clickable: true
                    color: entry.modelData.connected ? Colors.m3secondaryContainer : "transparent"
                    onClicked: {
                        if (entry.modelData.paired)
                            root.expanded = entry.open ? null : entry.modelData;
                        else
                            entry.modelData.pair();
                    }
                }

                RowLayout {
                    visible: entry.open
                    Layout.fillWidth: true
                    Layout.leftMargin: 16
                    Layout.rightMargin: 8
                    Layout.bottomMargin: 6
                    spacing: 8

                    Item { Layout.fillWidth: true }
                    M3Button {
                        text: entry.modelData.connected ? Translation.tr("Disconnect") : Translation.tr("Connect")
                        tonal: entry.modelData.connected
                        onClicked: entry.modelData.connected ? entry.modelData.disconnect() : entry.modelData.connect()
                    }
                    M3Button {
                        tonal: true
                        text: Translation.tr("Forget")
                        onClicked: {
                            entry.modelData.forget();
                            root.expanded = null;
                        }
                    }
                }
            }
        }
    }
}
