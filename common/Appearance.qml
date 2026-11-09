pragma Singleton

import QtQuick
import Quickshell

// Material 3 Expressive design tokens: shape, typography, motion, sizes.
// Colors live in Colors.qml; user-tunable values come from Config.
Singleton {
    id: root

    readonly property var options: Config.options.appearance

    // User scales (Settings > Interface): corners, text and spacing, applied to the token scales below.
    readonly property real cornerScale: Math.max(0, Math.min(2, options.cornerScale))
    readonly property real fontScale: Math.max(0.6, Math.min(2, options.fontScale))
    readonly property real densityScale: ({ "compact": 0.75, "comfortable": 1, "spacious": 1.25 })[options.density] ?? 1

    function corner(px) {
        return Math.round(px * cornerScale);
    }
    function text(px) {
        return Math.round(px * fontScale);
    }
    function gap(px) {
        return Math.round(px * densityScale);
    }

    // M3 shape scale (corner radii).
    readonly property QtObject rounding: QtObject {
        readonly property int extraSmall: root.corner(4)
        readonly property int small: root.corner(8)
        readonly property int medium: root.corner(12)
        readonly property int large: root.corner(16)
        readonly property int largeIncreased: root.corner(20)
        readonly property int extraLarge: root.corner(28)
        readonly property int extraLargeIncreased: root.corner(32)
        readonly property int extraExtraLarge: root.corner(48)
        readonly property int full: 9999
    }

    // Outline width for floating surfaces: depth comes from tone, so the outline is only
    // there when the surface is see-through (otherwise its edge would dissolve into the wallpaper).
    readonly property int edge: options.transparency && !ShellState.zen ? 1 : 0

    // Spacing scale (px); use these instead of loose numbers in layouts.
    readonly property QtObject space: QtObject {
        readonly property int xxs: root.gap(2)
        readonly property int xs: root.gap(4)
        readonly property int sm: root.gap(8)
        readonly property int md: root.gap(12)
        readonly property int lg: root.gap(16)
        readonly property int xl: root.gap(24)
        readonly property int xxl: root.gap(32)
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
        readonly property int panel: rounding.extraLarge
        readonly property int card: rounding.large
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
            readonly property int labelSmall: root.text(11)
            readonly property int labelMedium: root.text(12)
            readonly property int normal: root.text(13)
            readonly property int bodyMedium: root.text(14)
            readonly property int bodyLarge: root.text(16)
            readonly property int titleMedium: root.text(16)
            readonly property int titleLarge: root.text(22)
            readonly property int headlineSmall: root.text(24)
            readonly property int headlineMedium: root.text(28)
            readonly property int headlineLarge: root.text(32)
            readonly property int displaySmall: root.text(36)
            readonly property int displayMedium: root.text(45)
            readonly property int displayLarge: root.text(57)
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
        readonly property int spacing: root.gap(8)
        readonly property int panelPadding: root.gap(16)
    }

    // Surface color for panels/cards: translucent when transparency is on,
    // so the compositor blur shows through.
    function translucent(color, level) {
        // Focus Mode turns blur off, so nothing shows through either.
        if (!options.transparency || ShellState.zen)
            return color;
        return Qt.alpha(color, 1 - (level ?? options.transparencyLevel));
    }
}
