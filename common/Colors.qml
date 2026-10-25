pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Material 3 color roles. Loaded live from the palette that
// services/theme_updater.py generates from the wallpaper (see Theme.qml);
// the values below are the fallback baseline dark palette.
Singleton {
    id: root

    readonly property string path: `${Quickshell.env("XDG_STATE_HOME") || Quickshell.env("HOME") + "/.local/state"}/hi-shell/colors.json`

    property var scheme: ({})
    property string mode: "dark"
    // Wallpaper the palette was generated from (desktop layer draws it).
    property string wallpaper: ""
    readonly property bool dark: mode !== "light"

    function reload() {
        file.reload();
    }

    function role(name, fallback) {
        return scheme[name] ?? fallback;
    }

    readonly property color m3primary: role("primary", "#d0bcff")
    readonly property color m3onPrimary: role("on_primary", "#381e72")
    readonly property color m3primaryContainer: role("primary_container", "#4f378b")
    readonly property color m3onPrimaryContainer: role("on_primary_container", "#eaddff")
    readonly property color m3secondary: role("secondary", "#ccc2dc")
    readonly property color m3onSecondary: role("on_secondary", "#332d41")
    readonly property color m3secondaryContainer: role("secondary_container", "#4a4458")
    readonly property color m3onSecondaryContainer: role("on_secondary_container", "#e8def8")
    readonly property color m3tertiary: role("tertiary", "#efb8c8")
    readonly property color m3onTertiary: role("on_tertiary", "#492532")
    readonly property color m3tertiaryContainer: role("tertiary_container", "#633b48")
    readonly property color m3onTertiaryContainer: role("on_tertiary_container", "#ffd8e4")
    readonly property color m3surface: role("surface", "#141218")
    readonly property color m3surfaceContainerLow: role("surface_container_low", "#1d1b20")
    readonly property color m3onSurface: role("on_surface", "#e6e0e9")
    readonly property color m3onSurfaceVariant: role("on_surface_variant", "#cac4d0")
    readonly property color m3surfaceContainer: role("surface_container", "#211f26")
    readonly property color m3surfaceContainerHigh: role("surface_container_high", "#2b2930")
    readonly property color m3surfaceContainerHighest: role("surface_container_highest", "#36343b")
    readonly property color m3outline: role("outline", "#938f99")
    readonly property color m3outlineVariant: role("outline_variant", "#49454f")
    readonly property color m3error: role("error", "#f2b8b5")
    readonly property color m3errorContainer: role("error_container", "#8c1d18")
    readonly property color m3onErrorContainer: role("on_error_container", "#f9dedc")

    FileView {
        id: file
        path: root.path
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: {
            try {
                const data = JSON.parse(text());
                root.scheme = data.colors ?? {};
                root.mode = data.mode ?? "dark";
                root.wallpaper = data.wallpaper ?? "";
            } catch (e) {
                console.warn("Colors: invalid palette file", root.path, e);
            }
        }
    }
}
