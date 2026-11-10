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

    // Colors of your own (appearance.colorOverrides) win over the generated palette.
    function role(name, fallback) {
        const own = Config.options.appearance.colorOverrides;
        if (own && own[name] !== undefined && /^#[0-9a-fA-F]{6,8}$/.test(own[name]))
            return own[name];
        const next = scheme[name] ?? fallback;
        const was = prevScheme[name];
        if (fade >= 1 || was === undefined)
            return next;
        // A new palette (wallpaper, mode or scheme change) fades in from the old one.
        const a = Qt.color(was), b = Qt.color(next);
        return Qt.rgba(a.r + (b.r - a.r) * fade, a.g + (b.g - a.g) * fade, a.b + (b.b - a.b) * fade, a.a + (b.a - a.a) * fade);
    }

    // The palette before the last change and how far the change has come (0 .. 1).
    property var prevScheme: ({})
    property real fade: 1
    NumberAnimation {
        id: fadeAnim
        target: root
        property: "fade"
        from: 0
        to: 1
        easing.type: Easing.OutCubic
    }

    function applyScheme(next) {
        const ms = Config.options.appearance.paletteFade * Appearance.anim.speed;
        const changed = JSON.stringify(next) !== JSON.stringify(scheme);
        if (ms > 0 && changed && Object.keys(scheme).length > 0) {
            fadeAnim.stop();
            prevScheme = scheme;
            fade = 0;
            fadeAnim.duration = ms;
            scheme = next;
            fadeAnim.start();
        } else {
            scheme = next;
        }
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
    readonly property color m3surfaceDim: role("surface_dim", "#141218")
    readonly property color m3surfaceBright: role("surface_bright", "#3b383e")
    readonly property color m3surfaceContainerLowest: role("surface_container_lowest", "#0f0d13")
    readonly property color m3surfaceVariant: role("surface_variant", "#49454f")
    readonly property color m3inverseSurface: role("inverse_surface", "#e6e0e9")
    readonly property color m3inverseOnSurface: role("inverse_on_surface", "#322f35")
    readonly property color m3inversePrimary: role("inverse_primary", "#6750a4")
    readonly property color m3primaryFixed: role("primary_fixed", "#eaddff")
    readonly property color m3primaryFixedDim: role("primary_fixed_dim", "#d0bcff")
    readonly property color m3secondaryFixed: role("secondary_fixed", "#e8def8")
    readonly property color m3secondaryFixedDim: role("secondary_fixed_dim", "#ccc2dc")
    readonly property color m3tertiaryFixed: role("tertiary_fixed", "#ffd8e4")
    readonly property color m3tertiaryFixedDim: role("tertiary_fixed_dim", "#efb8c8")
    readonly property color m3scrim: role("scrim", "#000000")
    readonly property color m3shadow: role("shadow", "#000000")
    readonly property color m3onError: role("on_error", "#601410")
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
                root.applyScheme(data.colors ?? {});
                root.mode = data.mode ?? "dark";
                root.wallpaper = data.wallpaper ?? "";
            } catch (e) {
                console.warn("Colors: invalid palette file", root.path, e);
            }
        }
    }
}
