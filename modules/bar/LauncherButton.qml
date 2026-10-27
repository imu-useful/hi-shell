import QtQuick
import qs.common
import qs.common.widgets

// Left click: left sidebar. Right click: app launcher (also Super).
BarWidget {
    id: root

    clickable: true
    padding: 4
    contentWidth: thickness - padding * 2
    contentHeight: contentWidth
    onClicked: mouse => {
        if (mouse.button === Qt.RightButton)
            ShellState.launcherOpen = !ShellState.launcherOpen;
        else
            ShellState.sidebarLeftOpen = !ShellState.sidebarLeftOpen;
    }

    MaterialIcon {
        anchors.centerIn: parent
        icon: "auto_awesome"
        fill: root.hovered ? 1 : 0
        iconSize: 20
        color: Colors.m3primary
    }
}
