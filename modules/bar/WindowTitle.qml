import QtQuick
import Quickshell.Hyprland
import qs.common

// Title of the focused Hyprland window.
Text {
    readonly property var toplevel: Hyprland.activeToplevel

    text: toplevel && toplevel.title ? toplevel.title : "Desktop"
    elide: Text.ElideRight
    maximumLineCount: 1
    font.family: Style.fontFamily
    font.pixelSize: Style.fontSize
    color: Colors.m3onSurfaceVariant
}
