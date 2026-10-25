import QtQuick
import qs.common
import qs.common.widgets

// Opens the app launcher.
BarWidget {
    id: root

    clickable: true
    padding: 4
    contentWidth: thickness - padding * 2
    contentHeight: contentWidth
    onClicked: ShellState.launcherOpen = !ShellState.launcherOpen

    MaterialIcon {
        anchors.centerIn: parent
        icon: "auto_awesome"
        fill: root.hovered ? 1 : 0
        iconSize: 20
        color: Colors.m3primary
    }
}
