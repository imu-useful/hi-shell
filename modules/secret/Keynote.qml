import QtQuick
import Quickshell
import Quickshell.Io
import qs.common
import qs.common.widgets

// Keys "keynote", "presentation", "презентация" and "event": hi-shell presents itself the way a
// product keynote does. Black stage, big type, its own track (sounds/secret/keynote.ogg, 120 BPM,
// made by tools/make_secret_music.py). Every slide starts on a bar, words and tiles land on beats
// and everything pulses with the kick. The slides play on their own; → or Space jumps to the next
// one, ← back, and the music jumps with them. In order: the logo (the drums come in with it); "not
// just a shell"; a made-up desktop coming alive (KeynoteDesktop.qml) in a device frame tilting
// up; numbers counted from the install itself; a bento grid of features; the wallpaper and the
// colors made from it; "One more thing…" over a breakdown; and, on the drop, the finale
// (KeynoteFinale.qml) that loops until closed.
Item {
    id: root

    required property bool revealed
    // The arrow keys step through the slides (off for the first-run welcome, which plays it whole)
    property bool skippable: true
    // Text for a button that shows up once the finale's name is on screen ("" = no button)
    property string actionText: ""

    signal action()
    property real time: 0

    // [start, length] in seconds; the last one (the finale) has no end
    readonly property var slides: [[0, 8], [8, 6], [14, 8], [22, 6], [28, 8], [36, 6], [42, 4]]
    readonly property real finaleStart: 46
    readonly property int slideIndex: {
        if (time >= finaleStart)
            return slides.length;
        for (let i = slides.length - 1; i >= 0; i--)
            if (time >= slides[i][0])
                return i;
        return 0;
    }

    // The beat: the track has drums from 4 s to 42 s and from 46 s on, a kick every half second.
    // The sound reaches the speakers a little after the player starts, so the picture waits for it.
    readonly property real latency: 0.08
    readonly property real beatLength: 0.5
    readonly property real musicTime: time - latency
    readonly property bool groove: (musicTime >= 4 && musicTime < 42) || musicTime >= finaleStart
    readonly property real beatPhase: ((musicTime / beatLength) % 1 + 1) % 1
    readonly property bool downbeat: Math.floor(musicTime / beatLength) % 4 === 0
    // 1 on a kick (a bar's first one is the strongest), falling fast to 0
    readonly property real kick: groove ? Math.exp(-beatPhase * 7) * (downbeat ? 1 : 0.6) : 0
    // Where the music plays from (it restarts there when the slides jump)
    property real musicFrom: 0
    property bool musicOn: false

    readonly property real u: Math.min(width, height)
    readonly property real headline: Math.min(u * 0.12, width / 13)
    readonly property var accent: [Colors.m3primary, Colors.m3tertiary, Colors.m3secondary]
    readonly property var neon: ["#5ac8fa", "#bf5af2", "#ff375f"]

    property real qmlLines: 0
    property real commands: 0
    property real settings: 0

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
        time = starts[next];
        playFrom(time);
    }

    function playFrom(seconds) {
        musicOn = false;
        musicFrom = seconds;
        Qt.callLater(() => musicOn = true);
    }

    Component.onCompleted: playFrom(0)

    FrameAnimation {
        running: root.revealed
        onTriggered: root.time += frameTime
    }

    Shortcut { enabled: root.skippable; sequences: ["Right", "Space", "Return"]; onActivated: root.jump(1) }
    Shortcut { enabled: root.skippable; sequence: "Left"; onActivated: root.jump(-1) }

    // mpv loops the finale's part of the track (A-B); ffplay and pw-play just play it to the end
    Process {
        running: root.revealed && root.musicOn
        command: ["sh", "-c", `f="$1"; at="$2"; if command -v mpv >/dev/null; then exec mpv --no-video --really-quiet --start="$at" --ab-loop-a=46 --ab-loop-b=62 "$f";
            elif command -v ffplay >/dev/null; then exec ffplay -nodisp -autoexit -loglevel quiet -ss "$at" "$f";
            else exec pw-play "$f"; fi`, "sh", Quickshell.shellPath("sounds/secret/keynote.ogg"), String(root.musicFrom)]
    }

    Process {
        running: true
        command: ["sh", "-c", `cd "$1" || exit 1
            find -L . -name '*.qml' -not -path './.git/*' -exec cat {} + | wc -l
            sed -n '/^COMMANDS="/,/"$/p' sh/hi-shell | tr -d '"' | sed 's/^COMMANDS=//' | wc -w
            grep -cE '^\\s*property (var|bool|int|real|string|list|color|url)' common/ConfigOptions.qml`, "sh", Quickshell.shellPath("")]
        stdout: StdioCollector {
            onStreamFinished: {
                const n = text.trim().split(/\s+/).map(Number);
                root.qmlLines = n[0] || 40000;
                root.commands = n[1] || 50;
                root.settings = n[2] || 200;
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
            strength: (0.35 + 0.12 * root.kick) * root.ease(parent.t, 4, 1.5)
        }

        KeynoteText {

            kick: root.kick
            anchors.centerIn: parent
            text: Translation.tr("Introducing")
            size: root.headline * 0.42
            weight: Font.DemiBold
            color: "#a1a1a8"
            letterSpacing: size * 0.08
            shown: root.ease(parent.t, 0.5, 1.2) * root.clamp((3.8 - parent.t) / 0.4)
        }

        AnimatedLogo {
            anchors.centerIn: parent
            anchors.verticalCenterOffset: -root.u * 0.05
            height: root.u * 0.38
            playing: parent.t > 4 && root.revealed
            scale: (0.92 + 0.08 * root.ease(parent.t, 4, 2)) * (1 + 0.03 * root.kick)
        }

        KeynoteText {

            kick: root.kick
            anchors.horizontalCenter: parent.horizontalCenter
            y: parent.height * 0.79
            text: Translation.tr("The shell. Reimagined.")
            size: root.headline * 0.55
            colors: root.accent
            time: root.time
            shown: root.ease(parent.t, 6, 0.8)
        }
    }

    // ---- 1: the statement ------------------------------------------------------------------------

    Item {
        anchors.fill: parent
        readonly property real t: root.local(1)
        visible: opacity > 0
        opacity: root.stage(1)

        KeynoteText {

            kick: root.kick
            anchors.horizontalCenter: parent.horizontalCenter
            y: parent.height * 0.5 - height - root.ease(parent.t, 2, 0.6) * root.headline * 0.15
            text: Translation.tr("It's not just a shell.")
            size: root.headline * 0.8
            shown: root.ease(parent.t, 0, 0.7) * (1 - 0.6 * root.ease(parent.t, 2, 0.6))
        }

        KeynoteText {

            kick: root.kick
            anchors.horizontalCenter: parent.horizontalCenter
            y: parent.height * 0.5 + root.headline * 0.1
            text: Translation.tr("It's your whole desktop.")
            size: root.headline * 0.95
            weight: Font.Black
            colors: root.neon
            time: root.time
            shown: root.ease(parent.t, 2, 0.6)
        }
    }

    // ---- 2: the real desktop in a device frame ----------------------------------------------------

    Item {
        anchors.fill: parent
        readonly property real t: root.local(2)
        visible: opacity > 0
        opacity: root.stage(2)

        KeynoteText {

            kick: root.kick
            anchors.horizontalCenter: parent.horizontalCenter
            y: parent.height * 0.07
            text: Translation.tr("Your desktop.")
            size: root.headline * 0.6
            shown: root.ease(parent.t, 0, 0.7)
        }

        KeynoteText {

            kick: root.kick
            anchors.horizontalCenter: parent.horizontalCenter
            y: parent.height * 0.07 + root.headline * 0.72
            text: Translation.tr("Every pixel, rethought.")
            size: root.headline * 0.6
            color: "#86868b"
            shown: root.ease(parent.t, 0.5, 0.7)
        }

        KeynoteSlides.Glow {
            anchors.horizontalCenter: device.horizontalCenter
            anchors.verticalCenter: device.bottom
            width: device.width * 1.3
            height: device.height * 0.7
            tint: Colors.m3primary
            strength: (0.3 + 0.1 * root.kick) * root.ease(parent.t, 1, 2)
        }

        KeynoteSlides.Device {
            id: device

            readonly property real rise: root.ease(parent.t, 1, 2.5)

            width: Math.min(parent.width * 0.62, parent.height * 0.62 * root.width / Math.max(1, root.height))
            height: width * root.height / Math.max(1, root.width) + 12
            anchors.horizontalCenter: parent.horizontalCenter
            y: parent.height * 0.3 + (1 - rise) * parent.height * 0.35
            glare: root.clamp((parent.t - 4) / 1.6)
            opacity: Math.min(1, rise * 2)
            scale: (0.86 + 0.14 * rise) * (1 + 0.03 * root.clamp((parent.t - 3.5) / 4.5)) * (1 + 0.008 * root.kick)
            transform: Rotation {
                origin.x: device.width / 2
                origin.y: device.height
                axis { x: 1; y: 0; z: 0 }
                angle: 38 * (1 - device.rise)
            }

            KeynoteDesktop {
                anchors.fill: parent
                t: device.parent.t - 2.2
                clock: root.time
                kick: root.kick
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

            kick: root.kick
            anchors.horizontalCenter: parent.horizontalCenter
            y: parent.height * 0.16
            text: Translation.tr("Built different.")
            size: root.headline * 0.7
            shown: root.ease(parent.t, 0, 0.7)
        }

        Row {
            anchors.centerIn: parent
            anchors.verticalCenterOffset: root.u * 0.08
            spacing: root.width * 0.07

            KeynoteSlides.Stat {
                kick: root.kick
                value: root.qmlLines
                label: Translation.tr("lines of QML")
                size: root.headline * 0.95
                colors: root.neon
                time: root.time
                progress: root.ease(parent.parent.t, 1, 2)
            }

            KeynoteSlides.Stat {
                kick: root.kick
                value: root.commands
                label: Translation.tr("commands in hi")
                size: root.headline * 0.95
                colors: root.accent
                time: root.time
                progress: root.ease(parent.parent.t, 1.5, 2)
            }

            KeynoteSlides.Stat {
                kick: root.kick
                value: root.settings
                label: Translation.tr("settings")
                size: root.headline * 0.95
                colors: ["#30d158", "#64d2ff", "#30d158"]
                time: root.time
                progress: root.ease(parent.parent.t, 2, 2)
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

            kick: root.kick
            anchors.horizontalCenter: parent.horizontalCenter
            y: parent.height * 0.08
            text: Translation.tr("Everything. In one place.")
            size: root.headline * 0.6
            shown: root.ease(bento.t, 0, 0.7)
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
                    shown: root.ease(bento.t, 1 + index * 0.5, 0.6)
                    kick: root.kick
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

            kick: root.kick
            anchors.horizontalCenter: parent.horizontalCenter
            y: parent.height * 0.1
            text: Translation.tr("Your wallpaper.")
            size: root.headline * 0.7
            shown: root.ease(colorSlide.t, 0, 0.7)
        }

        KeynoteText {

            kick: root.kick
            anchors.horizontalCenter: parent.horizontalCenter
            y: parent.height * 0.1 + root.headline * 0.8
            text: Translation.tr("Your colors.")
            size: root.headline * 0.7
            weight: Font.Black
            colors: [Colors.m3primary, Colors.m3tertiary, Colors.m3secondary]
            time: root.time
            shown: root.ease(colorSlide.t, 2, 0.6)
        }

        KeynoteSlides.Device {
            id: card
            width: root.u * 0.62
            height: width * 9 / 16
            anchors.horizontalCenter: parent.horizontalCenter
            y: parent.height * 0.42
            opacity: root.ease(colorSlide.t, 0.5, 0.8)
            scale: (0.94 + 0.06 * opacity) * (1 - 0.12 * root.ease(colorSlide.t, 2, 1.2))
            glare: root.clamp((colorSlide.t - 1) / 1.4)

            Image {
                anchors.fill: parent
                source: Colors.wallpaper ? "file://" + Colors.wallpaper : ""
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                smooth: true
                mipmap: true
            }
        }

        Repeater {
            model: colorSlide.swatches.length

            Rectangle {
                id: swatch

                required property int index
                readonly property real fly: root.ease(colorSlide.t, 2.5 + index * 0.25, 1)
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
                scale: (0.3 + 0.7 * fly) * (1 + 0.12 * root.kick)
            }
        }
    }

    // ---- 6: one more thing ------------------------------------------------------------------------

    KeynoteText {

        kick: root.kick
        anchors.centerIn: parent
        visible: opacity > 0
        text: Translation.tr("One more thing…")
        size: root.headline * 0.55
        weight: Font.DemiBold
        color: "#a1a1a8"
        shown: root.ease(root.local(6), 0.5, 1.4) * root.clamp((root.slides[6][1] - root.local(6)) / 0.4)
    }

    // ---- the finale (KeynoteFinale.qml) -----------------------------------------------------------

    KeynoteFinale {
        anchors.fill: parent
        t: root.time - root.finaleStart
        time: root.time
        kick: root.kick
        headline: root.headline
        u: root.u
        visible: t > -0.2
        opacity: root.ease(t, 0, 0.4)
    }

    // ---- the button after the show (the welcome's "Get started") ----------------------------------

    Rectangle {
        id: actionButton

        readonly property real shown: root.actionText !== "" ? root.ease(root.time - root.finaleStart, 4, 0.8) : 0

        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: root.u * 0.13
        width: buttonLabel.implicitWidth + root.headline * 0.9
        height: root.headline * 0.62
        radius: height / 2
        visible: shown > 0
        opacity: shown
        scale: (0.9 + 0.1 * shown) * (buttonHover.hovered ? 1.05 : 1) * (1 + 0.02 * root.kick)
        color: buttonHover.hovered ? "white" : "#f2f2f7"
        Behavior on scale { NumberAnimation { duration: 120 } }

        // A soft halo around it, breathing with the music
        Rectangle {
            anchors.centerIn: parent
            z: -1
            width: parent.width + root.headline * 0.3 * (1 + root.kick)
            height: parent.height + root.headline * 0.3 * (1 + root.kick)
            radius: height / 2
            color: Qt.alpha(Colors.m3primary, 0.16)
        }

        Text {
            id: buttonLabel
            anchors.centerIn: parent
            text: root.actionText
            color: "#111114"
            font.family: Appearance.font.title
            font.pixelSize: root.headline * 0.24
            font.weight: Font.DemiBold
        }

        HoverHandler { id: buttonHover; cursorShape: Qt.PointingHandCursor }
        TapHandler { onTapped: root.action() }

        Shortcut {
            enabled: actionButton.visible
            sequences: ["Return", "Enter"]
            onActivated: root.action()
        }
    }
}
