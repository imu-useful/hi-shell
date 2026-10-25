import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import qs.common
import qs.common.widgets

// Session menu: lock, suspend, log out, reboot, power off.
BarWidget {
    id: root

    property bool menuOpen: false

    clickable: true
    active: menuOpen
    padding: 4
    contentWidth: thickness - padding * 2
    contentHeight: contentWidth
    onClicked: menuOpen = !menuOpen

    MaterialIcon {
        anchors.centerIn: parent
        icon: "power_settings_new"
        iconSize: 18
        color: root.active ? Colors.m3onSecondaryContainer : Colors.m3onSurface
    }

    StyledPopup {
        target: root
        pinned: root.menuOpen
        edge: root.popupEdge
        padding: 8
        onShownChanged: if (!shown) root.menuOpen = false

        ColumnLayout {
            spacing: 0

            Repeater {
                model: [
                    { icon: "lock", text: "Lock", run: () => Quickshell.execDetached(["loginctl", "lock-session"]) },
                    { icon: "bedtime", text: "Suspend", run: () => Quickshell.execDetached(["systemctl", "suspend"]) },
                    { icon: "logout", text: "Log out", run: () => Hyprland.dispatch("hl.dsp.exit()") },
                    { icon: "restart_alt", text: "Reboot", run: () => Quickshell.execDetached(["systemctl", "reboot"]) },
                    { icon: "power_settings_new", text: "Power off", run: () => Quickshell.execDetached(["systemctl", "poweroff"]) }
                ]

                ListRow {
                    required property var modelData
                    Layout.preferredWidth: 180
                    implicitHeight: 40
                    icon: modelData.icon
                    title: modelData.text
                    clickable: true
                    onClicked: {
                        root.menuOpen = false;
                        modelData.run();
                    }
                }
            }
        }
    }
}
