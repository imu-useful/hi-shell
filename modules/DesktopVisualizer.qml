import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.common
import qs.common.widgets
import qs.services

// Audio visualizer along the bottom of the desktop (Config desktop.visualizer, needs
// cava). Its own small surface under the windows: drawn inside the full-screen
// desktop, every bar update would redraw the wallpaper, frame and widgets too.
Scope {
    id: root

    readonly property var options: Config.options.desktop
    readonly property ShellScreen screen: Quickshell.screens.find(s => s.name === options.monitor) ?? Quickshell.screens[0] ?? null
    readonly property bool active: options.visualizer && options.widgets && Mpris.playing
        && !ShellState.desktopCovered && !ShellState.desktopEditing && Appearance.anim.speed > 0

    PanelWindow {
        id: window

        visible: root.active && root.screen !== null
        screen: root.screen
        anchors.left: true
        anchors.right: true
        anchors.bottom: true
        implicitHeight: 180
        exclusionMode: ExclusionMode.Ignore
        color: "transparent"
        // Clicks go through to the desktop.
        mask: Region {}

        WlrLayershell.namespace: "hi-shell-visualizer"
        WlrLayershell.layer: WlrLayer.Bottom

        Spectrum {
            anchors.fill: parent
            active: root.active
            bars: 64
            gap: 4
            minLength: 4
            color: Qt.alpha(Colors.m3primary, 0.55)
        }
    }
}
