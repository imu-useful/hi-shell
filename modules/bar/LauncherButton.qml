import QtQuick
import Quickshell.Io
import QtQuick.Effects
import qs.common
import qs.common.widgets

// The distribution's logo, in the wallpaper's primary color. Left click: left sidebar. Right click:
// app launcher (also Super). Without a logo file, the sparkle icon.
BarWidget {
    id: root

    // The logo file from /etc/os-release ("LOGO=archlinux-logo"), in the standard pixmaps folder.
    property string logoName: ""
    readonly property string logo: logoName !== "" ? `file:///usr/share/pixmaps/${logoName}.svg` : ""

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

    FileView {
        path: "/etc/os-release"
        printErrors: false
        onLoaded: {
            const line = text().split("\n").find(l => l.startsWith("LOGO="));
            root.logoName = line ? line.slice(5).replace(/"/g, "").trim() : "";
        }
    }

    Image {
        id: logoImage
        anchors.centerIn: parent
        width: parent.width
        height: parent.height
        visible: false
        source: root.logo
        sourceSize.width: 64
        sourceSize.height: 64
        fillMode: Image.PreserveAspectFit
        asynchronous: true
    }

    // Tinted to the primary color: the logo's own blue is only a shape.
    MultiEffect {
        anchors.centerIn: parent
        width: logoImage.width
        height: logoImage.height
        visible: logoImage.status === Image.Ready
        source: logoImage
        colorization: 1
        colorizationColor: root.hovered ? Qt.lighter(Colors.m3primary, 1.2) : Colors.m3primary
    }

    MaterialIcon {
        anchors.centerIn: parent
        icon: "auto_awesome"
        fill: root.hovered ? 1 : 0
        iconSize: 20
        color: Colors.m3primary
        visible: root.logo === "" || logoImage.status === Image.Error
    }
}
