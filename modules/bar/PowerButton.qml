import QtQuick
import qs.common
import qs.common.widgets

// Opens the session screen (lock, log out, suspend, reboot, power off).
BarWidget {
    id: root

    clickable: true
    active: ShellState.sessionOpen
    padding: 4
    contentWidth: thickness - padding * 2
    contentHeight: contentWidth
    onClicked: ShellState.sessionOpen = !ShellState.sessionOpen

    MaterialIcon {
        anchors.centerIn: parent
        icon: "power_settings_new"
        iconSize: 18
        color: root.active ? Colors.m3onSecondaryContainer : Colors.m3onSurface
    }
}
