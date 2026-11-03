import QtQuick
import QtQuick.Effects
import Quickshell.Widgets
import qs.common

// An app icon. With appearance.themedIcons it's one color, the palette's primary, so the icons
// follow the wallpaper (themed icons); otherwise the app's own colors.
Item {
    id: root

    property alias source: icon.source
    property int size: 24
    property color tint: Colors.m3primary
    readonly property bool themed: Config.options.appearance.themedIcons

    implicitWidth: size
    implicitHeight: size

    // Its picture is only the texture for the effect below.
    IconImage {
        id: icon
        anchors.fill: parent
        implicitSize: root.size
        visible: false
    }

    MultiEffect {
        anchors.fill: parent
        source: icon
        colorization: root.themed ? 1 : 0
        colorizationColor: root.tint
    }
}
