pragma Singleton

import QtQuick
import Quickshell

// Material 3 color roles. Static baseline (dark) palette for now;
// Stage 5 will regenerate this file from the wallpaper via matugen.
Singleton {
    readonly property color m3primary: "#d0bcff"
    readonly property color m3onPrimary: "#381e72"
    readonly property color m3primaryContainer: "#4f378b"
    readonly property color m3onPrimaryContainer: "#eaddff"
    readonly property color m3secondaryContainer: "#4a4458"
    readonly property color m3onSecondaryContainer: "#e8def8"
    readonly property color m3surface: "#141218"
    readonly property color m3onSurface: "#e6e0e9"
    readonly property color m3onSurfaceVariant: "#cac4d0"
    readonly property color m3surfaceContainer: "#211f26"
    readonly property color m3surfaceContainerHigh: "#2b2930"
    readonly property color m3surfaceContainerHighest: "#36343b"
    readonly property color m3outline: "#938f99"
    readonly property color m3outlineVariant: "#49454f"
    readonly property color m3error: "#f2b8b5"
}
