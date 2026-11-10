pragma Singleton

import QtQuick
import Quickshell

// Design tokens of the Terminal look: small square corners, a hairline outline on every surface,
// Space Grotesk text with monospace figures, short motion without spring. The colors stay
// Material You (Colors.qml, from the wallpaper); user-tunable values come from Config.
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

    // Corner radii. Small and square on purpose: nothing is a pill, `full` included (a "pill" is a
    // slightly softened rectangle, a "circle" a softened square); appearance.cornerScale scales them all.
    readonly property QtObject rounding: QtObject {
        readonly property int extraSmall: root.corner(2)
        readonly property int small: root.corner(2)
        readonly property int medium: root.corner(3)
        readonly property int large: root.corner(4)
        readonly property int largeIncreased: root.corner(4)
        readonly property int extraLarge: root.corner(6)
        readonly property int extraLargeIncreased: root.corner(6)
        readonly property int extraExtraLarge: root.corner(8)
        readonly property int full: root.corner(4)
    }

    // Outline width of panels, cards and controls: surfaces are told apart by their edge, not by tone,
    // so there's always one. appearance.borderWidth (-1 = auto) sets it by hand, 0 turns it off.
    readonly property int edge: options.borderWidth >= 0 ? options.borderWidth : 1

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

    // Corner radius per component kind.
    readonly property QtObject shape: QtObject {
        readonly property int panel: rounding.extraLarge
        readonly property int card: rounding.large
        readonly property int button: rounding.medium
        readonly property int chip: rounding.small
        readonly property int field: rounding.medium
        readonly property int tile: rounding.large
        readonly property int popup: rounding.large
    }

    readonly property QtObject font: QtObject {
        readonly property string main: root.options.fonts.main
        // appearance.textWeight and appearance.letterSpacing: the default weight and tracking of every text.
        readonly property int weight: ({ "light": Font.Light, "normal": Font.Normal, "medium": Font.Medium })[root.options.textWeight] ?? Font.Normal
        readonly property real letterSpacing: root.options.letterSpacing
        readonly property string title: root.options.fonts.title
        readonly property string mono: root.options.fonts.mono
        // Small UPPERCASE labels (section names, units, keys): monospace, tracked out.
        readonly property real labelSpacing: 1.2
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
        // appearance.motionStyle sets the feel (duration factor, how much the spatial curves overshoot);
        // appearance.animationBounce scales the overshoot on top of it (0 = no spring at all).
        readonly property var styleParams: ({
                "expressive": { time: 1, bounce: 1 },
                "smooth": { time: 1.2, bounce: 0.25 },
                "snappy": { time: 0.7, bounce: 0.6 }
            })[root.options.motionStyle] ?? { time: 1, bounce: 1 }
        readonly property real speed: ShellState.zen ? 0 : Math.max(0, root.options.animationSpeed) * styleParams.time
        readonly property real bounce: Math.max(0, root.options.animationBounce) * styleParams.bounce

        // Overshoot of a spatial curve (its control points above 1) scaled by `bounce`.
        function _spring(c) {
            const k = bounce;
            return [c[0], c[1] > 1 ? 1 + (c[1] - 1) * k : c[1], c[2], c[3] > 1 ? 1 + (c[3] - 1) * k : c[3], 1, 1];
        }

        readonly property list<real> spatialFast: _spring([0.42, 1.67, 0.21, 0.90])
        readonly property list<real> spatialDefault: _spring([0.38, 1.21, 0.22, 1.00])
        readonly property list<real> spatialSlow: _spring([0.39, 1.29, 0.35, 0.98])
        readonly property list<real> effects: [0.34, 0.80, 0.34, 1.00, 1, 1]
        readonly property list<real> emphasizedDecel: [0.05, 0.70, 0.10, 1.00, 1, 1]
        readonly property list<real> emphasizedAccel: [0.30, 0.00, 0.80, 0.15, 1, 1]

        // How popups (calendar, weather, AI, overview) and the sidebars appear: appearance.popupEffect and
        // appearance.sidebarEffect. A popup starts at `popScale` and `popShift` px away, and settles.
        readonly property string popupEffect: root.options.popupEffect
        readonly property real popScale: ({ "pop": 0.85, "drop": 0.55 })[popupEffect] ?? 1
        readonly property real popShift: popupEffect === "slide" ? 28 : 0
        readonly property string sidebarEffect: root.options.sidebarEffect
        readonly property real sidebarSlide: sidebarEffect === "slide" ? 1 : 0
        readonly property real panelSpeed: 1 / Math.max(0.1, root.options.panelSpeed)
        readonly property real barSpeed: 1 / Math.max(0.1, root.options.barSpeed)
        readonly property real notificationSpeed: 1 / Math.max(0.1, root.options.notificationSpeed)
        // How small a pressed button gets (appearance.pressScale): 1 = not at all.
        readonly property real pressScale: root.options.pressScale
        readonly property string launcherEffect: root.options.launcherEffect
        readonly property real launcherRise: launcherEffect === "rise" ? 1 : 0
        readonly property real launcherScale: launcherEffect === "pop" ? 0.85 : 1
        readonly property real sidebarScale: sidebarEffect === "pop" ? 0.9 : 1

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
        // flat: always solid; glass: see-through, at least a quarter, whatever the transparency switch.
        // Focus Mode and power saving turn blur off, so nothing shows through then, glass included.
        if (options.surfaceStyle === "flat" || ShellState.zen || Config.options.powerSaving.enabled || (!options.transparency && options.surfaceStyle !== "glass"))
            return color;
        const see = level ?? options.transparencyLevel;
        return Qt.alpha(color, 1 - (options.surfaceStyle === "glass" ? Math.max(see, 0.25) : see));
    }
}
