import QtQuick
import qs.common
import qs.common.widgets

// Left click: app launcher. Right click: left sidebar.
BarWidget {
    id: root

    clickable: true
    padding: 4
    contentWidth: thickness - padding * 2
    contentHeight: contentWidth
    onClicked: mouse => {
        if (mouse.button === Qt.RightButton)
            ShellState.sidebarLeftOpen = !ShellState.sidebarLeftOpen;
        else
            ShellState.launcherOpen = !ShellState.launcherOpen;
    }

    MaterialIcon {
        anchors.centerIn: parent
        icon: "auto_awesome"
        fill: root.hovered ? 1 : 0
        iconSize: 20
        color: Colors.m3primary
    }
}
