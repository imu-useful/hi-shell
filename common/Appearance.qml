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

    readonly property QtObject font: QtObject {
        readonly property string main: root.options.fonts.main
        readonly property string title: root.options.fonts.title
        readonly property string mono: root.options.fonts.mono
        readonly property string icon: root.options.fonts.icon

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
        readonly property real speed: Math.max(0, root.options.animationSpeed)

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
        if (!options.transparency)
            return color;
        return Qt.alpha(color, 1 - (level ?? options.transparencyLevel));
    }
}
