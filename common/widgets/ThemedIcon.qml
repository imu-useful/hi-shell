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
    // Load the picture off the GUI thread (long lists of icons).
    property bool asynchronous: false
    readonly property bool themed: Config.options.appearance.themedIcons

    implicitWidth: size
    implicitHeight: size

    // Its own colors are drawn as they are; the effect below (and its offscreen texture) only exists
    // while the icons are themed, so plain icons stay cheap.
    IconImage {
        id: icon
        anchors.fill: parent
        implicitSize: root.size
        asynchronous: root.asynchronous
        visible: !root.themed
    }

    MultiEffect {
        anchors.fill: parent
        visible: root.themed
        source: icon
        colorization: root.themed ? 1 : 0
        colorizationColor: root.tint
    }
}
