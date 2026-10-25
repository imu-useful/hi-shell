import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.common
import qs.modules.bar

// Rounded black screen corners over everything (Config appearance.screenCorners
// = radius in px, 0 = off). Click-through.
Variants {
    model: Config.options.appearance.screenCorners > 0 ? Quickshell.screens : []

    PanelWindow {
        id: window

        required property ShellScreen modelData
        readonly property int size: Config.options.appearance.screenCorners

        screen: modelData
        anchors.top: true
        anchors.bottom: true
        anchors.left: true
        anchors.right: true
        exclusionMode: ExclusionMode.Ignore
        mask: Region {}
        color: "transparent"

        WlrLayershell.namespace: "hi-shell-corners"
        WlrLayershell.layer: WlrLayer.Overlay

        Repeater {
            model: [[false, false], [true, false], [false, true], [true, true]]

            ScreenCorner {
                required property var modelData
                size: window.size
                color: "black"
                flipX: modelData[0]
                flipY: modelData[1]
                x: flipX ? window.width - size : 0
                y: flipY ? window.height - size : 0
            }
        }
    }
}
