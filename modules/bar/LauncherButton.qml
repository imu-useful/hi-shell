import QtQuick
import qs.common
import qs.common.widgets
import qs.services

// The distribution's logo in the wallpaper's primary color (Settings > Bar picks another one).
// Left click: left sidebar. Right click: app launcher (also Super). The sparkle icon when there's no logo.
BarWidget {
    id: root

    // The logo id: the one picked in the settings, else the system's (os-release ID).
    readonly property string logo: Config.options.bar.logo !== "auto" ? Config.options.bar.logo : Distro.logo

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

    DistroLogo {
        id: mark
        anchors.centerIn: parent
        width: parent.width
        height: parent.height
        logo: root.logo
        tint: root.hovered ? Qt.lighter(Colors.m3primary, 1.2) : Colors.m3primary
        visible: !mark.failed
    }

    MaterialIcon {
        anchors.centerIn: parent
        icon: "auto_awesome"
        fill: root.hovered ? 1 : 0
        iconSize: 20
        color: Colors.m3primary
        visible: mark.failed
    }
}
