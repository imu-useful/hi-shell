import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import qs.common
import qs.common.widgets

// Keys "keynote", "presentation", "презентация" and "event": hi-shell presents itself the way a
// product keynote does. Black stage, big type, slow fades. The slides play on their own; → or
// Space jumps to the next one, ← back. In order: the logo; "not just a shell"; the real desktop
// (a screenshot taken as the show opens) in a device frame tilting up; numbers counted from the
// install itself; a bento grid of features; the wallpaper and the colors made from it;
// "One more thing…"; and a finale over the neon show (EyeCandy.qml) that stays until closed.
Item {
    id: root

    required property bool revealed
    property real time: 0

    // [start, length] in seconds; the last one (the finale) has no end
    readonly property var slides: [[0, 7], [7, 5.5], [12.5, 7.5], [20, 7], [27, 8.5], [35.5, 7], [42.5, 4]]
    readonly property real finaleStart: 46.5
    readonly property int slideIndex: {
        if (time >= finaleStart)
            return slides.length;
        for (let i = slides.length - 1; i >= 0; i--)
            if (time >= slides[i][0])
                return i;
        return 0;
    }

    readonly property real u: Math.min(width, height)
    readonly property real headline: Math.min(u * 0.12, width / 13)
    readonly property var accent: [Colors.m3primary, Colors.m3tertiary, Colors.m3secondary]
    readonly property var neon: ["#5ac8fa", "#bf5af2", "#ff375f"]

    // Taken as the show opens; empty until grim is done (or if it fails)
    property string shot: ""
    readonly property string shotPath: `${Quickshell.env("XDG_RUNTIME_DIR") || "/tmp"}/hi-shell-keynote.png`
    property real qmlLines: 0
    property real commands: 0

    function clamp(x) {
        return Math.max(0, Math.min(1, x));
    }

    // Ease out (cubic) of the time since `at`, over `length` seconds
    function ease(t, at, length) {
        const x = clamp((t - at) / (length ?? 0.9));
        return 1 - Math.pow(1 - x, 3);
    }

    // How much slide `i` is on stage: fades in at its start, out over its last half second
    function stage(i) {
        const s = slides[i];
        const t = time - s[0];
        return clamp(t / 0.5) * clamp((s[1] - t) / 0.5);
    }

    function local(i) {
        return time - slides[i][0];
    }

    function jump(step) {
        const starts = slides.map(s => s[0]).concat([finaleStart]);
        const next = Math.max(0, Math.min(starts.length - 1, slideIndex + step));
        time = starts[next] + 0.01;
    }

    FrameAnimation {
        running: root.revealed
        onTriggered: root.time += frameTime
    }

    Shortcut { sequences: ["Right", "Space", "Return"]; onActivated: root.jump(1) }
    Shortcut { sequence: "Left"; onActivated: root.jump(-1) }

    Process {
        running: true
        command: ["grim", "-o", Hyprland.focusedMonitor?.name ?? "", root.shotPath]
        onExited: code => {
            if (code === 0)
                root.shot = "file://" + root.shotPath + "?" + Date.now();
        }
    }

    Process {
        running: true
        command: ["sh", "-c", `cd "$1" || exit 1
            find -L . -name '*.qml' -not -path './.git/*' -exec cat {} + | wc -l
            sed -n '/^COMMANDS="/,/"$/p' sh/hi-shell | tr -d '"' | sed 's/^COMMANDS=//' | wc -w`, "sh", Quickshell.shellPath("")]
        stdout: StdioCollector {
            onStreamFinished: {
                const n = text.trim().split(/\s+/).map(Number);
                root.qmlLines = n[0] || 40000;
                root.commands = n[1] || 50;
            }
        }
    }

    // ---- 0: the logo ------------------------------------------------------------------------------

    Item {
        anchors.fill: parent
        readonly property real t: root.local(0)
        visible: opacity > 0
        opacity: root.stage(0)

        KeynoteSlides.Glow {
            anchors.centerIn: parent
            width: root.u * 1.4 * (0.9 + 0.1 * Math.sin(root.time * 0.7))
            height: width * 0.7
            tint: Colors.m3primary
            strength: 0.35 * root.ease(parent.t, 1.6, 2)
        }

        KeynoteText {
            anchors.centerIn: parent
            text: Translation.tr("Introducing")
            size: root.headline * 0.42
            weight: Font.DemiBold
            color: "#a1a1a8"
            letterSpacing: size * 0.08
            shown: root.ease(parent.t, 0.5, 1.2) * root.clamp((2.2 - parent.t) / 0.5)
        }

        AnimatedLogo {
            anchors.centerIn: parent
            anchors.verticalCenterOffset: -root.u * 0.05
            height: root.u * 0.38
            playing: parent.t > 2.3 && root.revealed
            scale: 0.92 + 0.08 * root.ease(parent.t, 2.3, 2.5)
        }

        KeynoteText {
            anchors.horizontalCenter: parent.horizontalCenter
            y: parent.height * 0.79
            text: Translation.tr("The shell. Reimagined.")
            size: root.headline * 0.55
            colors: root.accent
            time: root.time
            shown: root.ease(parent.t, 4.2, 1.2)
        }
    }

    // ---- 1: the statement ------------------------------------------------------------------------

    Item {
        anchors.fill: parent
        readonly property real t: root.local(1)
        visible: opacity > 0
        opacity: root.stage(1)

        KeynoteText {
            anchors.horizontalCenter: parent.horizontalCenter
            y: parent.height * 0.5 - height - root.ease(parent.t, 2.3, 1) * root.headline * 0.15
            text: Translation.tr("It's not just a shell.")
            size: root.headline * 0.8
            shown: root.ease(parent.t, 0.3, 1) * (1 - 0.6 * root.ease(parent.t, 2.3, 1))
        }

        KeynoteText {
            anchors.horizontalCenter: parent.horizontalCenter
            y: parent.height * 0.5 + root.headline * 0.1
            text: Translation.tr("It's your whole desktop.")
            size: root.headline * 0.95
            weight: Font.Black
            colors: root.neon
            time: root.time
            shown: root.ease(parent.t, 2.5, 1.1)
        }
    }

    // ---- 2: the real desktop in a device frame ----------------------------------------------------

    Item {
        anchors.fill: parent
        readonly property real t: root.local(2)
        visible: opacity > 0
        opacity: root.stage(2)

        KeynoteText {
            anchors.horizontalCenter: parent.horizontalCenter
            y: parent.height * 0.07
            text: Translation.tr("Your desktop.")
            size: root.headline * 0.6
            shown: root.ease(parent.t, 0.2, 1)
        }

        KeynoteText {
            anchors.horizontalCenter: parent.horizontalCenter
            y: parent.height * 0.07 + root.headline * 0.72
            text: Translation.tr("Every pixel, rethought.")
            size: root.headline * 0.6
            color: "#86868b"
            shown: root.ease(parent.t, 0.6, 1)
        }

        KeynoteSlides.Glow {
            anchors.horizontalCenter: device.horizontalCenter
            anchors.verticalCenter: device.bottom
            width: device.width * 1.3
            height: device.height * 0.7
            tint: Colors.m3primary
            strength: 0.3 * root.ease(parent.t, 1.2, 2)
        }

        KeynoteSlides.Device {
            id: device

            readonly property real rise: root.ease(parent.t, 0.4, 2.6)

            width: Math.min(parent.width * 0.62, parent.height * 0.62 * root.width / Math.max(1, root.height))
            height: width * root.height / Math.max(1, root.width) + 12
            anchors.horizontalCenter: parent.horizontalCenter
            y: parent.height * 0.3 + (1 - rise) * parent.height * 0.35
            source: root.shot !== "" ? root.shot : (Colors.wallpaper ? "file://" + Colors.wallpaper : "")
            glare: root.clamp((parent.t - 3.2) / 1.6)
            opacity: Math.min(1, rise * 2)
            scale: (0.86 + 0.14 * rise) * (1 + 0.03 * root.clamp((parent.t - 3) / 4.5))
            transform: Rotation {
                origin.x: device.width / 2
                origin.y: device.height
                axis { x: 1; y: 0; z: 0 }
                angle: 38 * (1 - device.rise)
            }
        }
    }

    // ---- 3: the numbers ---------------------------------------------------------------------------

    Item {
        anchors.fill: parent
        readonly property real t: root.local(3)
        visible: opacity > 0
        opacity: root.stage(3)

        KeynoteText {
            anchors.horizontalCenter: parent.horizontalCenter
            y: parent.height * 0.16
            text: Translation.tr("Built different.")
            size: root.headline * 0.7
            shown: root.ease(parent.t, 0.2, 1)
        }

        Row {
            anchors.centerIn: parent
            anchors.verticalCenterOffset: root.u * 0.08
            spacing: root.width * 0.07

            KeynoteSlides.Stat {
                value: root.qmlLines
                label: Translation.tr("lines of QML")
                size: root.headline * 0.95
                colors: root.neon
                time: root.time
                progress: root.ease(parent.parent.t, 0.9, 2.2)
            }

            KeynoteSlides.Stat {
                value: root.commands
                label: Translation.tr("commands in hi")
                size: root.headline * 0.95
                colors: root.accent
                time: root.time
                progress: root.ease(parent.parent.t, 1.3, 2.2)
            }

            KeynoteSlides.Stat {
                value: 0
                suffix: " MB"
                label: Translation.tr("of Electron")
                size: root.headline * 0.95
                colors: ["#30d158", "#64d2ff", "#30d158"]
                time: root.time
                progress: root.ease(parent.parent.t, 1.7, 2.2)
            }
        }
    }

    // ---- 4: the features --------------------------------------------------------------------------

    Item {
        id: bento

        readonly property real t: root.local(4)
        // A 4 x 2 grid; [column, row, span] per tile
        readonly property var cells: [[0, 0, 2], [2, 0, 1], [3, 0, 1], [0, 1, 1], [1, 1, 1], [2, 1, 2]]
        readonly property var tiles: [
            ["auto_awesome", Translation.tr("Claude, built in"), Translation.tr("Ask anything, right from the desktop."), Colors.m3primary],
            ["palette", Translation.tr("Material You"), Translation.tr("Colors from your wallpaper."), Colors.m3tertiary],
            ["bolt", Translation.tr("Hyprland native"), Translation.tr("Smooth at any refresh rate."), "#ffd60a"],
            ["tune", Translation.tr("Control center"), Translation.tr("Wi-Fi, Bluetooth and sound."), Colors.m3secondary],
            ["terminal", Translation.tr("One command"), Translation.tr("hi does the rest."), "#30d158"],
            ["dashboard", Translation.tr("Bar, dock and widgets"), Translation.tr("Live, glanceable, yours."), "#5ac8fa"]
        ]
        readonly property real gridWidth: Math.min(parent.width * 0.8, parent.height * 1.22)
        readonly property real gap: gridWidth * 0.018
        readonly property real cellWidth: (gridWidth - gap * 3) / 4
        readonly property real cellHeight: cellWidth * 1.02

        anchors.fill: parent
        visible: opacity > 0
        opacity: root.stage(4)

        KeynoteText {
            anchors.horizontalCenter: parent.horizontalCenter
            y: parent.height * 0.08
            text: Translation.tr("Everything. In one place.")
            size: root.headline * 0.6
            shown: root.ease(bento.t, 0.2, 1)
        }

        Item {
            width: bento.gridWidth
            height: bento.cellHeight * 2 + bento.gap
            anchors.horizontalCenter: parent.horizontalCenter
            y: parent.height * 0.08 + root.headline * 0.95 + (parent.height * 0.92 - root.headline * 0.95 - height) / 2

            Repeater {
                model: bento.tiles.length

                KeynoteSlides.Tile {
                    required property int index
                    readonly property var cell: bento.cells[index]

                    x: cell[0] * (bento.cellWidth + bento.gap)
                    y: cell[1] * (bento.cellHeight + bento.gap)
                    width: bento.cellWidth * cell[2] + bento.gap * (cell[2] - 1)
                    height: bento.cellHeight
                    unit: bento.cellWidth / 16
                    icon: bento.tiles[index][0]
                    title: bento.tiles[index][1]
                    subtitle: bento.tiles[index][2]
                    tint: bento.tiles[index][3]
                    shown: root.ease(bento.t, 0.8 + index * 0.16, 1.1)
                }
            }
        }
    }

    // ---- 5: the wallpaper and its colors ---------------------------------------------------------

    Item {
        id: colorSlide

        readonly property real t: root.local(5)
        readonly property var swatches: [Colors.m3primary, Colors.m3secondary, Colors.m3tertiary, Colors.m3primaryContainer, Colors.m3tertiaryContainer, Colors.m3inversePrimary]

        anchors.fill: parent
        visible: opacity > 0
        opacity: root.stage(5)

        KeynoteText {
            anchors.horizontalCenter: parent.horizontalCenter
            y: parent.height * 0.1
            text: Translation.tr("Your wallpaper.")
            size: root.headline * 0.7
            shown: root.ease(colorSlide.t, 0.2, 1)
        }

        KeynoteText {
            anchors.horizontalCenter: parent.horizontalCenter
            y: parent.height * 0.1 + root.headline * 0.8
            text: Translation.tr("Your colors.")
            size: root.headline * 0.7
            weight: Font.Black
            colors: [Colors.m3primary, Colors.m3tertiary, Colors.m3secondary]
            time: root.time
            shown: root.ease(colorSlide.t, 1.6, 1)
        }

        KeynoteSlides.Device {
            id: card
            width: root.u * 0.62
            height: width * 9 / 16
            anchors.horizontalCenter: parent.horizontalCenter
            y: parent.height * 0.42
            source: Colors.wallpaper ? "file://" + Colors.wallpaper : ""
            opacity: root.ease(colorSlide.t, 0.5, 1)
            scale: (0.94 + 0.06 * opacity) * (1 - 0.12 * root.ease(colorSlide.t, 2, 1.2))
            glare: root.clamp((colorSlide.t - 1) / 1.4)
        }

        Repeater {
            model: colorSlide.swatches.length

            Rectangle {
                id: swatch

                required property int index
                readonly property real fly: root.ease(colorSlide.t, 2.1 + index * 0.13, 1.3)
                readonly property real size: root.u * 0.075
                readonly property real gap: size * 0.35
                // From the middle of the card out to a row under it
                readonly property real fromX: card.x + card.width / 2 - size / 2
                readonly property real fromY: card.y + card.height / 2 - size / 2
                readonly property real toX: colorSlide.width / 2 + (index - (colorSlide.swatches.length - 1) / 2) * (size + gap) - size / 2
                readonly property real toY: card.y + card.height * 0.94 + size * 0.4

                width: size
                height: size
                radius: size / 2
                color: colorSlide.swatches[index]
                border.color: Qt.rgba(1, 1, 1, 0.25)
                border.width: 1.5
                x: fromX + (toX - fromX) * fly
                y: fromY + (toY - fromY) * fly + Math.sin(fly * Math.PI) * -root.u * 0.12
                opacity: Math.min(1, fly * 3)
                scale: 0.3 + 0.7 * fly + 0.05 * Math.sin(root.time * 3 + index)
            }
        }
    }

    // ---- 6: one more thing ------------------------------------------------------------------------

    KeynoteText {
        anchors.centerIn: parent
        visible: opacity > 0
        text: Translation.tr("One more thing…")
        size: root.headline * 0.55
        weight: Font.DemiBold
        color: "#a1a1a8"
        shown: root.ease(root.local(6), 0.8, 1.4) * root.clamp((root.slides[6][1] - root.local(6)) / 0.6)
    }

    // ---- the finale -------------------------------------------------------------------------------

    Item {
        readonly property real t: root.time - root.finaleStart

        anchors.fill: parent
        visible: t > -0.2
        opacity: root.ease(t, 0, 2)

        Loader {
            anchors.fill: parent
            active: parent.visible
            sourceComponent: EyeCandy {
                revealed: root.revealed
                showCaptions: false
            }
        }

        Rectangle {
            anchors.fill: parent
            color: "black"
            opacity: 0.35
        }

        Column {
            anchors.centerIn: parent
            spacing: root.headline * 0.2

            KeynoteText {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "hi-shell"
                size: root.headline * 1.6
                weight: Font.Black
                shown: root.ease(parent.parent.t, 0.8, 1.4)
                scale: 1 + 0.025 * Math.exp(-((root.time * 128 / 60) % 1) * 5)
            }

            KeynoteText {
                anchors.horizontalCenter: parent.horizontalCenter
                text: Translation.tr("Free. Open source. Yours.")
                size: root.headline * 0.45
                weight: Font.DemiBold
                colors: ["#ffffff", "#e0d4ff", "#ffffff"]
                time: root.time
                shown: root.ease(parent.parent.t, 2.2, 1.2)
            }
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            anchors.bottomMargin: root.u * 0.06
            text: "github.com/imu-useful/hi-shell"
            color: Qt.rgba(1, 1, 1, 0.7)
            font.family: Appearance.font.title
            font.pixelSize: root.headline * 0.22
            font.weight: Font.Medium
            opacity: root.ease(parent.t, 3.4, 1.2)
        }
    }
}
