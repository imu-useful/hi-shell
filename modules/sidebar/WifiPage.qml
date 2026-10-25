import QtQuick
import QtQuick.Layouts
import Quickshell.Networking
import qs.common
import qs.common.widgets

// Wi-Fi networks: scans while open. Tap a saved / open network to connect, a
// secured new one to enter its password. The connected network can be
// disconnected, saved ones forgotten.
StyledFlickable {
    id: root

    readonly property var device: Networking.devices.values.find(d => d.type === DeviceType.Wifi) ?? null
    readonly property var networks: (device?.networks.values ?? []).filter(n => n.name)
        .sort((a, b) => (b.connected - a.connected) || (b.known - a.known) || (b.signalStrength - a.signalStrength))
    property var expanded: null

    contentHeight: column.implicitHeight

    Component.onCompleted: if (device) device.scannerEnabled = true
    Component.onDestruction: if (device) device.scannerEnabled = false

    function signalIcon(s) {
        return s > 0.75 ? "network_wifi" : s > 0.5 ? "network_wifi_3_bar" : s > 0.25 ? "network_wifi_2_bar" : "network_wifi_1_bar";
    }

    ColumnLayout {
        id: column
        width: root.width
        spacing: 2

        ListRow {
            Layout.fillWidth: true
            icon: "wifi"
            title: Translation.tr("Wi-Fi")
            subtitle: !Networking.wifiHardwareEnabled ? Translation.tr("Blocked by hardware switch") : root.device?.scannerEnabled ? Translation.tr("Scanning…") : ""
            M3Switch {
                checked: Networking.wifiEnabled
                enabled: Networking.wifiHardwareEnabled
                onToggled: checked => Networking.wifiEnabled = checked
            }
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.topMargin: 4
            Layout.bottomMargin: 4
            implicitHeight: 1
            color: Colors.m3outlineVariant
        }

        StyledText {
            visible: Networking.wifiEnabled && root.networks.length === 0
            Layout.leftMargin: 16
            text: Translation.tr("Looking for networks…")
            color: Colors.m3onSurfaceVariant
        }

        Repeater {
            model: Networking.wifiEnabled ? root.networks : []

            ColumnLayout {
                id: entry

                required property var modelData
                readonly property bool secured: modelData.security !== WifiSecurityType.Open && modelData.security !== WifiSecurityType.Owe
                readonly property bool open: root.expanded === modelData
                property string failure: ""

                Layout.fillWidth: true
                spacing: 0

                Connections {
                    target: entry.modelData
                    function onConnectionFailed(reason) {
                        entry.failure = reason === ConnectionFailReason.NoSecrets || reason === ConnectionFailReason.WifiAuthTimeout ? Translation.tr("Wrong password?") : Translation.tr("Couldn't connect");
                        root.expanded = entry.modelData;
                    }
                    function onConnectedChanged() {
                        if (entry.modelData.connected) {
                            entry.failure = "";
                            if (root.expanded === entry.modelData)
                                root.expanded = null;
                        }
                    }
                }

                ListRow {
                    Layout.fillWidth: true
                    icon: root.signalIcon(entry.modelData.signalStrength)
                    title: entry.modelData.name
                    subtitle: entry.modelData.stateChanging ? Translation.tr("Connecting…") : entry.modelData.connected ? Translation.tr("Connected") : entry.failure || (entry.modelData.known ? Translation.tr("Saved") : entry.secured ? Translation.tr("Secured") : Translation.tr("Open"))
                    clickable: true
                    color: entry.modelData.connected ? Colors.m3secondaryContainer : "transparent"
                    onClicked: {
                        if (entry.modelData.connected || entry.modelData.known && entry.failure === "") {
                            root.expanded = entry.open ? null : entry.modelData;
                            if (!entry.modelData.connected)
                                entry.modelData.connect();
                        } else if (entry.secured) {
                            root.expanded = entry.open ? null : entry.modelData;
                        } else {
                            entry.modelData.connect();
                        }
                    }

                    MaterialIcon {
                        visible: entry.secured
                        icon: "lock"
                        iconSize: 16
                    }
                }

                // Details: password for new secured networks, disconnect / forget for others.
                RowLayout {
                    visible: entry.open
                    Layout.fillWidth: true
                    Layout.leftMargin: 16
                    Layout.rightMargin: 8
                    Layout.bottomMargin: 6
                    spacing: 8

                    Rectangle {
                        visible: !entry.modelData.connected && (!entry.modelData.known || entry.failure !== "")
                        Layout.fillWidth: true
                        implicitHeight: 40
                        radius: 20
                        color: Colors.m3surfaceContainerHighest

                        TextInput {
                            id: password
                            anchors.fill: parent
                            anchors.leftMargin: 16
                            anchors.rightMargin: 16
                            verticalAlignment: TextInput.AlignVCenter
                            echoMode: TextInput.Password
                            font.family: Appearance.font.main
                            font.pixelSize: Appearance.font.size.bodyMedium
                            color: Colors.m3onSurface
                            clip: true
                            focus: entry.open
                            onAccepted: {
                                entry.failure = "";
                                entry.modelData.connectWithPsk(text);
                            }

                            StyledText {
                                anchors.fill: parent
                                visible: password.text === ""
                                text: Translation.tr("Password")
                                color: Colors.m3outline
                            }
                        }
                    }
                    M3Button {
                        visible: !entry.modelData.connected && (!entry.modelData.known || entry.failure !== "")
                        text: Translation.tr("Connect")
                        onClicked: password.accepted()
                    }
                    Item {
                        visible: entry.modelData.connected || entry.modelData.known && entry.failure === ""
                        Layout.fillWidth: true
                    }
                    M3Button {
                        visible: entry.modelData.connected
                        tonal: true
                        text: Translation.tr("Disconnect")
                        onClicked: entry.modelData.disconnect()
                    }
                    M3Button {
                        visible: entry.modelData.known
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
