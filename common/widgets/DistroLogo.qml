import QtQuick
import QtQuick.Effects
import Quickshell
import qs.common

// A distribution's logo from common/icons/distros (by its id: archlinux, nixos, cachyos, ...), tinted
// to a color. `failed` when there's no such logo: the caller shows something else.
Item {
    id: root

    property string logo: ""
    property color tint: Colors.m3primary
    readonly property bool ready: image.status === Image.Ready
    readonly property bool failed: logo === "" || image.status === Image.Error

    implicitWidth: 32
    implicitHeight: 32

    Image {
        id: image
        anchors.fill: parent
        visible: false
        source: root.logo !== "" ? `file://${Quickshell.shellDir}/common/icons/distros/${root.logo}.svg` : ""
        sourceSize.width: 96
        sourceSize.height: 96
        fillMode: Image.PreserveAspectFit
        asynchronous: true
    }

    // Monochrome: the logos' own colors are only shapes.
    MultiEffect {
        anchors.fill: parent
        visible: root.ready
        source: image
        colorization: 1
        colorizationColor: root.tint
    }
}
