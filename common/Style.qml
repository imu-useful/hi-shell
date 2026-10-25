pragma Singleton

import QtQuick
import Quickshell

// Shared sizing / typography tokens.
Singleton {
    readonly property int barHeight: 40
    readonly property int barMargin: 6
    readonly property int radiusFull: 999
    readonly property int radiusLarge: 16
    readonly property int radiusMedium: 12
    readonly property int spacing: 8

    readonly property string fontFamily: "sans-serif"
    readonly property string iconFont: "Material Symbols Rounded"
    readonly property int fontSize: 13

    // Used for desktop entries with Terminal=true
    readonly property string terminal: "kitty"
}
