import QtQuick
import qs.common
import qs.common.widgets

// The keynote's finale, over the music's drop, looping until the show is closed. Silky light
// (silk.frag), rising bokeh and a halo stay all along, and the camera kicks with the beat; in
// front, four scenes of a bar pair each (4 s) take turns, with a flash on every change: the name
// in brushed metal, its letters flying together from all over, god rays (rays.frag) behind it and
// a red/cyan split on every kick; words slammed in one per beat; the features orbiting a glowing
// "hi"; and the name again with a burst of sparks over a wall of interface cards streaming past
// in 3D.
Item {
    id: root

    // Seconds since the finale began (the music's drop), the show's clock, the beat (0..1)
    property real t: 0
    property real time: 0
    property real kick: 0
    // The keynote's headline size and the screen's shorter side
    property real headline: 100
    property real u: 1000

    // The camera: a push on every kick, a slow sway
    scale: 1.025 + 0.012 * kick
    rotation: Math.sin(time * 0.25) * 0.6

    readonly property real sceneLength: 4
    readonly property int scene: t < 0 ? 0 : Math.floor(t / sceneLength) % 4
    readonly property real p: t < 0 ? 0 : t % sceneLength
    // 0..1 through the current bar (a bar is 2 s)
    readonly property real bar: t < 0 ? 0 : (t % 2) / 2
    readonly property real beat: 0.5

    readonly property var words: [Translation.tr("Fast."), Translation.tr("Smooth."), Translation.tr("Beautiful."), Translation.tr("Open."),
        Translation.tr("Free."), Translation.tr("Alive."), Translation.tr("Yours."), "hi."]
    readonly property var palettes: [["#5ac8fa", "#bf5af2", "#ff375f"], [Colors.m3primary, Colors.m3tertiary, Colors.m3secondary],
        ["#30d158", "#64d2ff", "#30d158"], ["#ffd60a", "#ff9f0a", "#ff375f"]]
    // The interface cards of the wall: [icon, label, color]
    readonly property var cards: [["wifi", Translation.tr("Wi-Fi"), "#5ac8fa"], ["music_note", Translation.tr("Now playing"), "#bf5af2"], ["wallpaper", Translation.tr("Wallpapers"), "#ff9f0a"],
        ["calendar_month", Translation.tr("Calendar"), "#ff375f"], ["notifications", Translation.tr("Notifications"), "#ffd60a"], ["bluetooth", Translation.tr("Bluetooth"), "#0a84ff"],
        ["auto_awesome", "Claude", Colors.m3primary], ["screenshot_region", Translation.tr("Screenshot"), "#30d158"], ["translate", Translation.tr("Translate"), "#64d2ff"],
        ["calculate", Translation.tr("Calculator"), "#ff9f0a"], ["dark_mode", Translation.tr("Dark mode"), "#8e8ef0"], ["volume_up", Translation.tr("Volume"), "#30d158"]]
    readonly property var features: [["auto_awesome", Colors.m3primary], ["palette", Colors.m3tertiary], ["bolt", "#ffd60a"],
        ["tune", Colors.m3secondary], ["terminal", "#30d158"], ["dashboard", "#5ac8fa"]]

    function clamp(x) {
        return Math.max(0, Math.min(1, x));
    }

    // 0 -> 1 with an overshoot
    function back(x) {
        const c = clamp(x), k = 1.9;
        return 1 + (k + 1) * Math.pow(c - 1, 3) + k * Math.pow(c - 1, 2);
    }

    function ease(x) {
        const c = clamp(x);
        return 1 - Math.pow(1 - c, 3);
    }

    // How much a scene is on: in over `fadeIn` s, out over the last `fadeOut` s
    function within(i, fadeIn, fadeOut) {
        return scene === i ? clamp(p / fadeIn) * clamp((sceneLength - p) / fadeOut) : 0;
    }

    ShaderEffect {
        anchors.fill: parent
        property vector2d res: Qt.vector2d(width, height)
        property real time: root.time
        property real kick: root.kick
        property color c0: Colors.m3primary
        property color c1: Colors.m3tertiary
        property color c2: Colors.m3secondary
        fragmentShader: Qt.resolvedUrl("silk.frag.qsb")
    }

    // God rays from behind the name, while it's on
    ShaderEffect {
        anchors.fill: parent
        property vector2d res: Qt.vector2d(width, height)
        property vector2d center: Qt.vector2d(width / 2, height / 2 - root.headline * 0.25)
        property real time: root.time
        property real kick: root.kick
        property color tint: Qt.lighter(Colors.m3primary, 1.2)
        property color tint2: "#ffffff"
        fragmentShader: Qt.resolvedUrl("rays.frag.qsb")
        opacity: name.shown
        visible: opacity > 0.01
    }

    // ---- scene 3's backdrop: a wall of interface cards streaming past in 3D ----------------------

    Item {
        id: wall

        readonly property real shown: root.within(3, 0.35, 0.3)
        readonly property real cardWidth: root.u * 0.4
        readonly property real cardHeight: root.u * 0.13
        readonly property real gap: root.u * 0.025

        anchors.centerIn: parent
        width: parent.width * 1.6
        height: (cardHeight + gap) * 5
        visible: shown > 0
        opacity: shown * 0.42
        transform: [
            Rotation {
                origin.x: wall.width / 2
                origin.y: wall.height / 2
                axis { x: 1; y: -0.6; z: 0.15 }
                angle: 32
            },
            Scale {
                origin.x: wall.width / 2
                origin.y: wall.height / 2
                xScale: 1.15 - 0.15 * wall.shown
                yScale: xScale
            }
        ]

        Repeater {
            model: 5

            Item {
                id: lane

                required property int index
                // Lanes run in turns left and right, at their own speeds
                readonly property real speed: (index % 2 ? -1 : 1) * root.u * (0.12 + 0.04 * index)
                readonly property real span: root.cards.length * (wall.cardWidth + wall.gap)

                y: index * (wall.cardHeight + wall.gap)
                width: wall.width
                height: wall.cardHeight

                Repeater {
                    model: root.cards.length * 2

                    Rectangle {
                        required property int index
                        readonly property var card: root.cards[(index + lane.index * 5) % root.cards.length]

                        x: ((index * (wall.cardWidth + wall.gap) + root.t * lane.speed) % (lane.span * 2) + lane.span * 2) % (lane.span * 2) - lane.span * 0.4
                        width: wall.cardWidth
                        height: wall.cardHeight
                        radius: height * 0.28
                        color: "#141418"
                        border.color: Qt.alpha(card[2], 0.35 + 0.4 * root.kick)
                        border.width: 1.5

                        Rectangle {
                            x: parent.height * 0.18
                            anchors.verticalCenter: parent.verticalCenter
                            width: parent.height * 0.64
                            height: width
                            radius: width * 0.3
                            color: parent.card[2]
                            MaterialIcon { anchors.centerIn: parent; icon: parent.parent.card[0]; iconSize: parent.width * 0.58; fill: 1; color: "white" }
                        }

                        Text {
                            x: parent.height * 0.98
                            width: parent.width - x - parent.height * 0.25
                            anchors.verticalCenter: parent.verticalCenter
                            elide: Text.ElideRight
                            text: parent.card[1]
                            color: "white"
                            font.family: Appearance.font.title
                            font.pixelSize: parent.height * 0.24
                            font.weight: Font.DemiBold
                        }
                    }
                }
            }
        }
    }

    // Shade behind the name, so it reads over the wall (two layers: one wide, one dense)
    Repeater {
        model: [[26, 13], [17, 7.5]]

        KeynoteSlides.Glow {
            required property var modelData
            anchors.centerIn: parent
            anchors.verticalCenterOffset: root.headline * 0.2
            width: root.headline * modelData[0]
            height: root.headline * modelData[1]
            tint: "black"
            strength: wall.shown
            visible: wall.visible
        }
    }

    // Bokeh: soft motes of light rising slowly, twinkling, brighter on the beat
    Repeater {
        model: 40

        KeynoteSlides.Glow {
            required property int index
            readonly property real seed: (index * 0.6180339) % 1
            readonly property real speed: 0.012 + 0.02 * ((index * 0.37) % 1)
            readonly property real rise: ((root.t * speed + seed) % 1 + 1) % 1

            width: root.u * (0.025 + 0.06 * ((index * 0.73) % 1))
            height: width
            x: root.width * ((index * 0.3819 + 0.05) % 1) + Math.sin(root.t * 0.4 + index) * root.u * 0.03 - width / 2
            y: root.height * (1.1 - rise * 1.2) - height / 2
            tint: [Colors.m3primary, Colors.m3tertiary, "#ffffff"][index % 3]
            strength: Math.sin(rise * Math.PI) * (0.25 + 0.2 * Math.sin(root.t * 1.7 + index * 2.1) + 0.35 * root.kick) * root.ease(root.t - 0.5 - seed * 2)
        }
    }

    // A halo in the middle, breathing with the kick
    KeynoteSlides.Glow {
        anchors.centerIn: parent
        anchors.verticalCenterOffset: -root.headline * 0.25
        width: root.headline * 9
        height: root.headline * 4
        tint: Colors.m3primary
        strength: (0.22 + 0.25 * root.kick) * root.ease(root.t / 0.6)
    }

    // ---- scenes 0 and 3: the name ---------------------------------------------------------------

    Item {
        id: name

        // On through scenes 3 and 0 (which follow each other), off for 1 and 2
        readonly property real shown: root.t < 4 ? root.ease(root.t / 0.6) * root.clamp((4 - root.t) / 0.25)
            : root.scene === 3 ? root.clamp(root.p / 0.2) : root.scene === 0 ? root.clamp((4 - root.p) / 0.25) : 0

        anchors.fill: parent
        visible: shown > 0
        opacity: shown
        scale: 1 + (1 - shown) * 0.15

        // A thin ring of light leaving the name on each bar's first beat
        Repeater {
            model: 2

            Rectangle {
                required property int index
                // Two rings take turns: this one runs on every other bar
                readonly property real q: index === Math.floor((root.t / 2) % 2) ? root.bar : 1

                anchors.centerIn: parent
                anchors.verticalCenterOffset: -root.headline * 0.25
                width: root.headline * 3 * (1 + q * 4)
                height: width
                radius: width / 2
                color: "transparent"
                border.width: Math.max(1, root.headline * 0.05 * (1 - q))
                border.color: Qt.alpha(Qt.lighter(Colors.m3primary, 1.3), 0.55 * Math.pow(1 - q, 1.5))
                visible: root.t > 0 && q < 1
            }
        }

        // Scene 3 opens with a burst: sparks shooting out from the middle
        Repeater {
            model: 36

            Rectangle {
                required property int index
                readonly property real q: root.scene === 3 ? root.ease(root.p / 1.4) : 1
                readonly property real angle: index / 36 * Math.PI * 2 + (index % 3) * 0.05
                readonly property real reach: root.u * (0.25 + 0.5 * ((index * 0.618) % 1)) * q

                visible: root.scene === 3 && q < 1
                width: root.u * (0.05 + 0.08 * ((index * 0.41) % 1)) * (1 - q * 0.6)
                height: Math.max(2, root.u * 0.006)
                radius: height / 2
                x: root.width / 2 + Math.cos(angle) * reach - width / 2
                y: root.height / 2 - root.headline * 0.25 + Math.sin(angle) * reach - height / 2
                rotation: angle * 180 / Math.PI
                color: [Colors.m3primary, "#ffffff", Colors.m3tertiary, "#5ac8fa"][index % 4]
                opacity: 1 - q
            }
        }

        Column {
            anchors.centerIn: parent
            spacing: root.headline * 0.2

            // The name, a letter at a time: as its scene begins the letters fly together from all
            // over, spinning, and snap into place; a glint runs along them; on every kick the
            // letters split into red and cyan for a moment
            Row {
                id: letters

                // Seconds since the letters started flying in (scene 0 from the finale's start, scene 3)
                readonly property real since: root.scene === 3 ? root.p : root.t < 4 ? root.t : 99

                anchors.horizontalCenter: parent.horizontalCenter
                spacing: -root.headline * 0.03
                scale: 1 + 0.035 * root.kick

                Repeater {
                    model: "hi-shell".length

                    Item {
                        id: letter

                        required property int index
                        readonly property real seedX: Math.sin(index * 12.9898) * 43758.5453 % 1
                        readonly property real seedY: Math.sin(index * 78.233) * 12345.678 % 1
                        readonly property real fly: root.back((letters.since - index * 0.06) / 0.7)
                        readonly property real away: 1 - Math.min(1, fly)

                        implicitWidth: glyph.implicitWidth
                        implicitHeight: glyph.implicitHeight

                        transform: Translate {
                            x: letter.seedX * root.u * 1.2 * letter.away
                            y: letter.seedY * root.u * 0.9 * letter.away
                        }
                        rotation: (letter.seedX * 540) * letter.away
                        opacity: Math.min(1, (letters.since - index * 0.06) * 4)

                        Repeater {
                            model: [["#ff2d55", -1], ["#30d5ff", 1]]

                            Text {
                                required property var modelData
                                x: modelData[1] * root.headline * 0.05 * root.kick
                                text: "hi-shell"[letter.index]
                                color: modelData[0]
                                opacity: 0.75 * root.kick
                                font.family: Appearance.font.title
                                font.pixelSize: root.headline * 1.6
                                font.weight: Font.Black
                                font.letterSpacing: -root.headline * 1.6 * 0.02
                            }
                        }

                        KeynoteText {
                            id: glyph
                            text: "hi-shell"[letter.index]
                            size: root.headline * 1.6
                            weight: Font.Black
                            colors: ["#c9cedb", "#ffffff", "#aeb4c4"]
                            time: root.time * 0.5 + letter.index * 0.2
                            shine: (letters.since - 0.9 - letter.index * 0.07) / 0.45
                            shown: 1
                        }
                    }
                }
            }

            KeynoteText {
                kick: root.kick
                anchors.horizontalCenter: parent.horizontalCenter
                text: Translation.tr("Free. Open source. Yours.")
                size: root.headline * 0.45
                weight: Font.DemiBold
                colors: ["#ffffff", Qt.lighter(Colors.m3primary, 1.15), "#ffffff"]
                time: root.time
                shown: root.t < 4 ? root.ease((root.t - 2) / 0.8) : 1
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
            opacity: root.t < 4 ? root.clamp(root.t - 2.5) : 1
        }
    }

    // ---- scene 1: a word on every beat ----------------------------------------------------------

    Item {
        anchors.fill: parent
        visible: root.scene === 1

        KeynoteText {
            id: word

            readonly property int index: Math.min(root.words.length - 1, Math.floor(root.p / root.beat))
            // 0..1 through this word's beat
            readonly property real q: (root.p % root.beat) / root.beat

            anchors.centerIn: parent
            text: root.words[index]
            size: Math.min(root.headline * 2.1, root.width / Math.max(4, text.length) * 1.5)
            weight: Font.Black
            colors: root.palettes[index % root.palettes.length]
            time: root.time
            shown: root.clamp((1 - q) / 0.15)
            // Slammed in: big and tilted, snapping into place within the beat
            scale: 1.45 - 0.45 * root.ease(q * 4)
            rotation: (index % 2 ? 4 : -4) * (1 - root.ease(q * 4))
        }
    }

    // ---- scene 2: the features orbiting a glowing "hi" ------------------------------------------

    Item {
        id: orbit

        readonly property real shown: root.within(2, 0.4, 0.3)
        readonly property real spin: root.p * 0.9

        anchors.fill: parent
        visible: shown > 0
        opacity: Math.min(1, shown * 1.5)

        Repeater {
            model: root.features.length

            Rectangle {
                required property int index
                readonly property real angle: index / root.features.length * Math.PI * 2 + orbit.spin
                // -1 at the back, 1 at the front
                readonly property real depth: Math.sin(angle)
                readonly property real reach: root.u * 0.42 * orbit.shown

                z: depth
                width: root.u * 0.15
                height: width
                radius: width * 0.28
                x: root.width / 2 + Math.cos(angle) * reach * 1.5 - width / 2
                y: root.height / 2 + depth * reach * 0.38 - height / 2
                scale: (0.65 + 0.35 * (depth + 1) / 2) * (1 + 0.12 * root.kick)
                opacity: 0.45 + 0.55 * (depth + 1) / 2
                color: "#16161a"
                border.color: Qt.alpha(root.features[index][1], 0.6)
                border.width: 2

                MaterialIcon {
                    anchors.centerIn: parent
                    icon: root.features[index][0]
                    iconSize: parent.width * 0.55
                    fill: 1
                    color: root.features[index][1]
                }
            }
        }

        Rectangle {
            z: 0
            anchors.centerIn: parent
            width: root.u * 0.26 * (1 + 0.06 * root.kick)
            height: width
            radius: width / 2
            gradient: Gradient {
                GradientStop { position: 0; color: Qt.lighter(Colors.m3primary, 1.2) }
                GradientStop { position: 1; color: Colors.m3tertiary }
            }
            scale: root.ease(root.p / 0.5)

            Text {
                anchors.centerIn: parent
                text: "hi"
                color: "#101014"
                font.family: Appearance.font.title
                font.pixelSize: parent.width * 0.42
                font.weight: Font.Black
            }
        }
    }

    // A flash on every change of scene
    Rectangle {
        anchors.fill: parent
        color: "white"
        opacity: root.t >= root.sceneLength ? Math.exp(-root.p * 9) * 0.45 : 0
        visible: opacity > 0.01
    }
}
