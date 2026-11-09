pragma Singleton

import QtQuick
import Quickshell

// Material 3 Expressive design tokens: shape, typography, motion, sizes.
// Colors live in Colors.qml; user-tunable values come from Config.
Singleton {
    id: root

    readonly property var options: Config.options.appearance

    // M3 shape scale (corner radii).
    readonly property QtObject rounding: QtObject {
        readonly property int extraSmall: 4
        readonly property int small: 8
        readonly property int medium: 12
        readonly property int large: 16
        readonly property int largeIncreased: 20
        readonly property int extraLarge: 28
        readonly property int extraLargeIncreased: 32
        readonly property int extraExtraLarge: 48
        readonly property int full: 9999
    }

    // Outline width for floating surfaces: depth comes from tone, so the outline is only
    // there when the surface is see-through (otherwise its edge would dissolve into the wallpaper).
    readonly property int edge: (options.transparency || glass) && !ShellState.zen ? 1 : 0

    // The design: "material" (Material You) or "glass" (Liquid Glass).
    readonly property bool glass: options.design === "glass"

    // Outline color of floating surfaces: a faint tone line, or the bright rim of a pane of glass.
    readonly property color edgeColor: glass ? Qt.alpha("white", Colors.dark ? 0.3 : 0.65) : Qt.alpha(Colors.m3outlineVariant, 0.6)

    // Spacing scale (px); use these instead of loose numbers in layouts.
    readonly property QtObject space: QtObject {
        readonly property int xxs: 2
        readonly property int xs: 4
        readonly property int sm: 8
        readonly property int md: 12
        readonly property int lg: 16
        readonly property int xl: 24
        readonly property int xxl: 32
    }

    // M3 state layer opacities (hover / focus / press / drag / disabled content).
    readonly property QtObject state: QtObject {
        readonly property real hover: 0.08
        readonly property real focus: 0.10
        readonly property real press: 0.10
        readonly property real drag: 0.16
        readonly property real disabledContent: 0.38
        readonly property real disabledContainer: 0.12
    }

    // Corner radius per component kind; the "Soft Tonal" look is tuned here.
    readonly property QtObject shape: QtObject {
        readonly property int panel: root.glass ? rounding.extraLargeIncreased : rounding.extraLarge
        readonly property int card: root.glass ? rounding.largeIncreased : rounding.large
        readonly property int button: rounding.full
        readonly property int chip: rounding.small
        readonly property int field: rounding.full
        readonly property int tile: rounding.largeIncreased
        readonly property int popup: rounding.large
    }

    readonly property QtObject font: QtObject {
        readonly property string main: root.options.fonts.main
        readonly property string title: root.options.fonts.title
        readonly property string mono: root.options.fonts.mono
        // The shell's own cut-down copy when it's there (IconFont).
        readonly property string icon: IconFont.name || root.options.fonts.icon

        // M3 type scale (px); `normal` is the bar's compact body size.
        readonly property QtObject size: QtObject {
            readonly property int labelSmall: 11
            readonly property int labelMedium: 12
            readonly property int normal: 13
            readonly property int bodyMedium: 14
            readonly property int bodyLarge: 16
            readonly property int titleMedium: 16
            readonly property int titleLarge: 22
            readonly property int headlineSmall: 24
            readonly property int headlineMedium: 28
            readonly property int headlineLarge: 32
            readonly property int displaySmall: 36
            readonly property int displayMedium: 45
            readonly property int displayLarge: 57
        }
    }

    // M3 Expressive motion. Spatial curves overshoot slightly (springy), effect
    // curves don't; use spatial for position/size and effects for opacity/color.
    // Durations are scaled by Config appearance.animationSpeed.
    readonly property QtObject anim: QtObject {
        readonly property real speed: ShellState.zen ? 0 : Math.max(0, root.options.animationSpeed)

        readonly property list<real> spatialFast: [0.42, 1.67, 0.21, 0.90, 1, 1]
        readonly property list<real> spatialDefault: [0.38, 1.21, 0.22, 1.00, 1, 1]
        readonly property list<real> spatialSlow: [0.39, 1.29, 0.35, 0.98, 1, 1]
        readonly property list<real> effects: [0.34, 0.80, 0.34, 1.00, 1, 1]
        readonly property list<real> emphasizedDecel: [0.05, 0.70, 0.10, 1.00, 1, 1]
        readonly property list<real> emphasizedAccel: [0.30, 0.00, 0.80, 0.15, 1, 1]

        readonly property int fast: 150 * speed
        readonly property int normal: 250 * speed
        readonly property int slow: 400 * speed
        readonly property int spatial: 500 * speed
    }

    readonly property QtObject sizes: QtObject {
        readonly property int barHeight: Config.options.bar.height
        readonly property int barMargin: Config.options.bar.margin
        readonly property int spacing: 8
        readonly property int panelPadding: 16
    }

    // Surface color for panels/cards: translucent when transparency is on,
    // so the compositor blur shows through.
    function translucent(color, level) {
        // Focus Mode turns blur off, so nothing shows through either.
        if (!options.transparency || ShellState.zen)
            return color;
        const base = level ?? options.transparencyLevel;
        // Glass is frosted: much more of the blurred background shows through.
        if (!glass)
            return Qt.alpha(color, 1 - base);
        // A touch of white and much more of the blurred background; not less see-through than a clear pane.
        return Qt.alpha(Qt.tint(color, Qt.rgba(1, 1, 1, 0.1)), 1 - Math.max(0.55, Math.min(0.7, base + 0.15)));
    }
}
