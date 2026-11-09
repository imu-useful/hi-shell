import QtQuick
import QtQuick.Shapes
import qs.common
import qs.common.widgets
import qs.common.shapes

// Keys "hyperos", "hyper os", "xiaomi": a silent show in a bold, dense interface style. Four
// scenes: a lock screen (the real time in giant numerals, a planet in front of them), a capsule at
// the top that morphs between music, a timer and a call, a spread of data widgets counting up, and
// glass cards drifting at different depths. The planet is drawn by planet.frag, the rest are items.
Item {
    id: root

    required property bool revealed
    property real time: 0

    readonly property real sceneLength: 7
    readonly property real cycle: sceneLength * 4
    readonly property int sceneIndex: Math.floor((time % cycle) / sceneLength)
    readonly property real sceneTime: (time % cycle) - sceneIndex * sceneLength
    readonly property var captions: ["HyperOS", Translation.tr("Alive"), Translation.tr("At a glance"), Translation.tr("Made for you")]

    readonly property real u: Math.min(width, height)
    readonly property color accent: "#ff6a1a"
    readonly property color glass: Qt.rgba(1, 1, 1, 0.07)
    readonly property color glassBorder: Qt.rgba(1, 1, 1, 0.14)
    readonly property color textSecondary: "#a7a3b3"

    property string clockText: ""
    property string dateText: ""

    function refreshClock() {
        const now = new Date();
        clockText = Qt.formatTime(now, "HH:mm");
        dateText = Qt.formatDate(now, "dddd, d MMMM");
    }

    Component.onCompleted: refreshClock()

    Timer {
        interval: 1000
        running: root.revealed
        repeat: true
        onTriggered: root.refreshClock()
    }

    FrameAnimation {
        running: root.revealed
        onTriggered: root.time += frameTime
    }

    function clamp(x) {
        return Math.max(0, Math.min(1, x));
    }

    function spring(p) {
        const x = clamp(p);
        return 1 - Math.exp(-7 * x) * Math.cos(13 * x);
    }

    function enter(at) {
        return spring((sceneTime - at) / 0.6);
    }

    function leave(order) {
        return clamp((sceneLength - sceneTime - order * 0.04) / 0.3);
    }

    // ---- backdrop --------------------------------------------------------------------------------

    Rectangle {
        anchors.fill: parent
        gradient: Gradient {
            GradientStop { position: 0; color: "#07060f" }
            GradientStop { position: 1; color: "#17112a" }
        }
    }

    Repeater {
        model: 46
        Rectangle {
            required property int index
            readonly property real seed: Math.abs(Math.sin(index * 12.9898) * 43758.5453) % 1
            readonly property real seed2: Math.abs(Math.sin(index * 78.233) * 12345.678) % 1
            x: seed * root.width
            y: seed2 * root.height
            width: 1 + (index % 3)
            height: width
            radius: width / 2
            color: "white"
            opacity: 0.25 + 0.5 * (0.5 + 0.5 * Math.sin(root.time * (0.8 + seed) + index))
        }
    }

    LetterCaption {
        x: root.width * 0.07
        y: root.height * 0.8
        text: root.captions[root.sceneIndex]
        time: root.time
        sceneTime: root.sceneTime
        sceneLength: root.sceneLength
        hue: 0.06
        fontSize: Math.min(96, root.height / 11)
        saturation: 0.9
        lightness: 0.7
        z: 20
    }

    // ---- scene 0: lock screen -----------------------------------------------------------------

    Item {
        visible: root.sceneIndex === 0
        anchors.fill: parent

        readonly property real inP: root.enter(0.1)
        readonly property real outP: root.leave(0)

        StyledText {
            anchors.horizontalCenter: parent.horizontalCenter
            y: root.height * 0.1 - (1 - parent.inP) * 30
            text: root.dateText
            font.pixelSize: root.u * 0.04
            font.weight: Font.Medium
            font.capitalization: Font.Capitalize
            color: root.textSecondary
            opacity: Math.min(1, parent.inP) * parent.outP
        }

        // The numerals sit behind the planet
        StyledText {
            id: digits
            anchors.horizontalCenter: parent.horizontalCenter
            y: root.height * 0.17 + (1 - parent.inP) * root.u * 0.12
            text: root.clockText
            font.family: Appearance.font.title
            font.pixelSize: root.u * 0.42
            font.weight: Font.Black
            font.letterSpacing: -root.u * 0.01
            elide: Text.ElideNone
            color: "white"
            opacity: Math.min(1, parent.inP * 1.4) * 0.92 * parent.outP
            layer.enabled: true
        }

        ShaderEffect {
            readonly property real size: root.u * 0.5 * 1.35 * (0.55 + 0.45 * parent.inP) * (0.9 + 0.1 * parent.outP)
            width: size
            height: size
            x: root.width / 2 - width / 2
            y: root.height * 0.72 - height / 2 + (1 - parent.inP) * root.u * 0.1
            opacity: Math.min(1, parent.inP * 1.5) * parent.outP
            property real time: root.time
            property color colA: "#ff7a2a"
            property color colB: "#5a2aa8"
            property color glow: "#6fb8ff"
            fragmentShader: Qt.resolvedUrl("planet.frag.qsb")
        }
    }

    // ---- scene 1: the capsule ------------------------------------------------------------------

    Item {
        id: island
        visible: root.sceneIndex === 1
        anchors.fill: parent

        // 0 compact, 1 music, 2 timer, 3 call
        readonly property real t: root.sceneTime
        readonly property int state: t < 1.0 ? 0 : t < 3.2 ? 1 : t < 5.0 ? 2 : t < 6.3 ? 3 : 0
        readonly property var dims: [[0.17, 0.055], [0.74, 0.15], [0.46, 0.13], [0.8, 0.3]]
        readonly property var changes: [1.0, 3.2, 5.0, 6.3]
        readonly property real sinceChange: Math.min(...changes.map(c => t - c).filter(d => d >= 0).concat([99]))

        Rectangle {
            id: capsule
            width: root.u * island.dims[island.state][0]
            height: root.u * island.dims[island.state][1]
            radius: Math.min(height / 2, root.u * 0.07)
            x: (root.width - width) / 2
            y: root.height * 0.07
            color: "#000000"
            border.color: Qt.rgba(1, 1, 1, 0.12)
            border.width: 2
            clip: true
            opacity: root.leave(0)
            scale: 0.9 + 0.1 * root.leave(0)

            Behavior on width { NumberAnimation { duration: 560; easing.type: Easing.OutBack; easing.overshoot: 1.25 } }
            Behavior on height { NumberAnimation { duration: 560; easing.type: Easing.OutBack; easing.overshoot: 1.25 } }

            // Compact: just the sensor dot
            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                x: parent.width * 0.7
                width: capsule.height * 0.34
                height: width
                radius: width / 2
                color: "#1b1b22"
                opacity: island.state === 0 ? 1 : 0
                Behavior on opacity { NumberAnimation { duration: 180 } }
            }

            // Music
            Item {
                anchors.fill: parent
                opacity: island.state === 1 ? 1 : 0
                Behavior on opacity { NumberAnimation { duration: 220 } }

                MaterialShape {
                    id: art
                    x: capsule.height * 0.2
                    anchors.verticalCenter: parent.verticalCenter
                    width: capsule.height * 0.6
                    height: width
                    shape: "square"
                    animated: false
                    color: root.accent
                    MaterialIcon {
                        anchors.centerIn: parent
                        icon: "music_note"
                        iconSize: parent.width * 0.55
                        fill: 1
                        color: "#ffffff"
                    }
                }
                Column {
                    anchors.verticalCenter: parent.verticalCenter
                    x: art.x + art.width + capsule.height * 0.2
                    StyledText {
                        text: "hi-shell"
                        font.pixelSize: capsule.height * 0.22
                        font.weight: Font.DemiBold
                        color: "#ffffff"
                    }
                    StyledText {
                        text: Translation.tr("Now playing")
                        font.pixelSize: capsule.height * 0.17
                        color: root.textSecondary
                    }
                }
                Row {
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.right: parent.right
                    anchors.rightMargin: capsule.height * 0.3
                    spacing: capsule.height * 0.05
                    Repeater {
                        model: 6
                        Rectangle {
                            required property int index
                            anchors.verticalCenter: parent.verticalCenter
                            width: capsule.height * 0.06
                            height: capsule.height * (0.12 + 0.3 * (0.5 + 0.5 * Math.sin(root.time * 7 + index * 1.3)))
                            radius: width / 2
                            color: root.accent
                        }
                    }
                }
            }

            // Timer
            Item {
                anchors.fill: parent
                opacity: island.state === 2 ? 1 : 0
                Behavior on opacity { NumberAnimation { duration: 220 } }

                Shape {
                    id: timerRing
                    x: capsule.height * 0.2
                    anchors.verticalCenter: parent.verticalCenter
                    width: capsule.height * 0.6
                    height: width
                    ShapePath {
                        strokeColor: Qt.rgba(1, 1, 1, 0.15)
                        strokeWidth: capsule.height * 0.07
                        fillColor: "transparent"
                        PathAngleArc { centerX: timerRing.width / 2; centerY: timerRing.width / 2; radiusX: timerRing.width * 0.42; radiusY: timerRing.width * 0.42; startAngle: 0; sweepAngle: 360 }
                    }
                    ShapePath {
                        strokeColor: root.accent
                        strokeWidth: capsule.height * 0.07
                        capStyle: ShapePath.RoundCap
                        fillColor: "transparent"
                        PathAngleArc { centerX: timerRing.width / 2; centerY: timerRing.width / 2; radiusX: timerRing.width * 0.42; radiusY: timerRing.width * 0.42; startAngle: -90; sweepAngle: 360 * root.clamp((island.t - 3.2) / 1.8) }
                    }
                }
                StyledText {
                    anchors.verticalCenter: parent.verticalCenter
                    x: timerRing.x + timerRing.width + capsule.height * 0.25
                    text: "00:" + String(Math.max(0, 5 - Math.floor(island.t - 3.2))).padStart(2, "0")
                    font.family: Appearance.font.mono
                    font.pixelSize: capsule.height * 0.34
                    font.weight: Font.Bold
                    color: "#ffffff"
                }
            }

            // Call
            Item {
                anchors.fill: parent
                opacity: island.state === 3 ? 1 : 0
                Behavior on opacity { NumberAnimation { duration: 220 } }

                Rectangle {
                    id: avatar
                    x: capsule.height * 0.12
                    y: capsule.height * 0.12
                    width: capsule.height * 0.3
                    height: width
                    radius: width / 2
                    color: root.accent
                    StyledText {
                        anchors.centerIn: parent
                        text: "h"
                        font.pixelSize: parent.width * 0.55
                        font.weight: Font.Bold
                        color: "#ffffff"
                    }
                }
                Column {
                    x: avatar.x + avatar.width + capsule.height * 0.08
                    y: capsule.height * 0.12
                    StyledText {
                        text: "hi-shell"
                        font.pixelSize: capsule.height * 0.12
                        font.weight: Font.DemiBold
                        color: "#ffffff"
                    }
                    StyledText {
                        text: Translation.tr("Incoming call")
                        font.pixelSize: capsule.height * 0.09
                        color: root.textSecondary
                    }
                }
                Row {
                    anchors.horizontalCenter: parent.horizontalCenter
                    y: capsule.height * 0.55
                    spacing: capsule.height * 0.25
                    Repeater {
                        model: [["call_end", "#ff453a"], ["call", "#30d158"]]
                        Rectangle {
                            required property var modelData
                            width: capsule.height * 0.3
                            height: width
                            radius: width / 2
                            color: modelData[1]
                            MaterialIcon {
                                anchors.centerIn: parent
                                icon: parent.modelData[0]
                                iconSize: parent.width * 0.5
                                fill: 1
                                color: "#ffffff"
                            }
                        }
                    }
                }
            }
        }

        // A ring that leaves the capsule each time it changes shape
        Rectangle {
            readonly property real k: island.sinceChange < 1 ? island.sinceChange : 1
            width: capsule.width + root.u * 0.12 * k
            height: capsule.height + root.u * 0.12 * k
            radius: Math.min(height / 2, root.u * 0.07 + root.u * 0.06 * k)
            x: (root.width - width) / 2
            y: capsule.y - (height - capsule.height) / 2
            color: "transparent"
            border.color: root.accent
            border.width: 3
            opacity: island.sinceChange < 1 ? 0.7 * (1 - k) : 0
        }
    }

    // ---- scene 2: widgets ----------------------------------------------------------------------

    Item {
        visible: root.sceneIndex === 2
        anchors.fill: parent

        Repeater {
            model: [0, 1, 2, 3]

            Rectangle {
                id: card

                required property int index
                readonly property real inP: root.enter(0.15 + index * 0.12)
                readonly property real outP: root.leave(index)
                // What the numbers have reached, 0..1
                readonly property real count: root.clamp((root.sceneTime - 0.5 - index * 0.12) / 1.6)
                readonly property real eased: 1 - Math.pow(1 - count, 3)

                width: root.u * 0.42
                height: root.u * 0.3
                radius: root.u * 0.05
                x: root.width / 2 + ((index % 2) - 0.5) * (width + root.u * 0.035) - width / 2
                y: root.height * 0.47 + (Math.floor(index / 2) - 0.5) * (height + root.u * 0.035) - height / 2 + (1 - inP) * 50
                color: root.glass
                border.color: root.glassBorder
                border.width: 2
                opacity: Math.min(1, inP * 1.5) * outP
                scale: (0.85 + 0.15 * inP) * (0.92 + 0.08 * outP)

                // Weather
                Item {
                    anchors.fill: parent
                    visible: card.index === 0
                    MaterialIcon {
                        x: root.u * 0.035
                        y: root.u * 0.03
                        icon: "wb_sunny"
                        iconSize: root.u * 0.07
                        fill: 1
                        color: root.accent
                        rotation: root.time * 20
                    }
                    StyledText {
                        x: root.u * 0.035
                        anchors.bottom: parent.bottom
                        anchors.bottomMargin: root.u * 0.02
                        text: Math.round(-6 + 9 * card.eased) + "°"
                        font.family: Appearance.font.title
                        font.pixelSize: root.u * 0.14
                        font.weight: Font.Black
                        color: "#ffffff"
                    }
                    StyledText {
                        anchors.right: parent.right
                        anchors.rightMargin: root.u * 0.035
                        y: root.u * 0.04
                        text: Translation.tr("Sunny")
                        font.pixelSize: root.u * 0.032
                        color: root.textSecondary
                    }
                }

                // Battery ring
                Item {
                    anchors.fill: parent
                    visible: card.index === 1
                    Shape {
                        id: battery
                        anchors.centerIn: parent
                        width: root.u * 0.22
                        height: width
                        ShapePath {
                            strokeColor: Qt.rgba(1, 1, 1, 0.13)
                            strokeWidth: root.u * 0.022
                            fillColor: "transparent"
                            PathAngleArc { centerX: battery.width / 2; centerY: battery.width / 2; radiusX: battery.width * 0.44; radiusY: battery.width * 0.44; startAngle: 0; sweepAngle: 360 }
                        }
                        ShapePath {
                            strokeColor: root.accent
                            strokeWidth: root.u * 0.022
                            capStyle: ShapePath.RoundCap
                            fillColor: "transparent"
                            PathAngleArc { centerX: battery.width / 2; centerY: battery.width / 2; radiusX: battery.width * 0.44; radiusY: battery.width * 0.44; startAngle: -90; sweepAngle: 360 * 0.86 * card.eased }
                        }
                    }
                    StyledText {
                        anchors.centerIn: parent
                        text: Math.round(86 * card.eased) + "%"
                        font.family: Appearance.font.title
                        font.pixelSize: root.u * 0.075
                        font.weight: Font.Black
                        color: "#ffffff"
                    }
                }

                // Steps
                Item {
                    anchors.fill: parent
                    visible: card.index === 2
                    StyledText {
                        x: root.u * 0.035
                        y: root.u * 0.025
                        text: Translation.tr("Steps")
                        font.pixelSize: root.u * 0.032
                        color: root.textSecondary
                    }
                    StyledText {
                        x: root.u * 0.035
                        y: root.u * 0.06
                        text: Math.round(8412 * card.eased)
                        font.family: Appearance.font.title
                        font.pixelSize: root.u * 0.085
                        font.weight: Font.Black
                        color: "#ffffff"
                    }
                    Row {
                        anchors.bottom: parent.bottom
                        anchors.bottomMargin: root.u * 0.03
                        x: root.u * 0.035
                        spacing: root.u * 0.014
                        Repeater {
                            model: [0.5, 0.8, 0.4, 0.95, 0.65, 0.85, 0.6]
                            Rectangle {
                                required property int index
                                required property real modelData
                                anchors.bottom: parent.bottom
                                width: root.u * 0.03
                                height: root.u * 0.085 * modelData * card.eased
                                radius: width / 2
                                color: index === 3 ? root.accent : Qt.rgba(1, 1, 1, 0.3)
                            }
                        }
                    }
                }

                // Heart rate
                Item {
                    anchors.fill: parent
                    visible: card.index === 3
                    MaterialIcon {
                        x: root.u * 0.035
                        y: root.u * 0.03
                        icon: "favorite"
                        iconSize: root.u * 0.07
                        fill: 1
                        color: "#ff453a"
                        scale: 1 + 0.18 * Math.pow(Math.max(0, Math.sin(root.time * 7)), 3)
                    }
                    StyledText {
                        x: root.u * 0.035
                        anchors.bottom: parent.bottom
                        anchors.bottomMargin: root.u * 0.02
                        text: Math.round(60 + 12 * card.eased)
                        font.family: Appearance.font.title
                        font.pixelSize: root.u * 0.14
                        font.weight: Font.Black
                        color: "#ffffff"
                    }
                    StyledText {
                        anchors.right: parent.right
                        anchors.rightMargin: root.u * 0.035
                        anchors.bottom: parent.bottom
                        anchors.bottomMargin: root.u * 0.04
                        text: "bpm"
                        font.pixelSize: root.u * 0.032
                        color: root.textSecondary
                    }
                }
            }
        }
    }

    // ---- scene 3: glass cards at different depths -------------------------------------------------

    Item {
        visible: root.sceneIndex === 3
        anchors.fill: parent

        // Thin rings turning slowly behind the cards
        Repeater {
            model: 3
            Rectangle {
                required property int index
                readonly property real inP: root.enter(0.1 + index * 0.1)
                width: root.u * (0.5 + index * 0.28) * (0.7 + 0.3 * inP)
                height: width
                radius: width / 2
                x: root.width / 2 - width / 2
                y: root.height * 0.46 - height / 2
                color: "transparent"
                border.color: Qt.rgba(1, 1, 1, 0.1)
                border.width: 2
                opacity: Math.min(1, inP) * root.leave(0)
                rotation: root.time * (10 + index * 5)
            }
        }

        Repeater {
            model: [["mode_standby", Translation.tr("Island"), -0.56, -0.12, 1.0], ["widgets", Translation.tr("Widgets"), 0.46, -0.22, 0.8], ["wallpaper", Translation.tr("Wallpaper"), -0.18, 0.2, 1.2], ["tune", Translation.tr("Controls"), 0.58, 0.26, 0.7], ["center_focus_strong", Translation.tr("Focus"), -0.74, 0.0, 0.6]]

            Rectangle {
                id: glassCard

                required property int index
                required property var modelData
                readonly property real depth: modelData[4]
                readonly property real inP: root.enter(0.2 + index * 0.12)
                readonly property real outP: root.leave(index)

                width: root.u * 0.34 * depth
                height: root.u * 0.17 * depth
                radius: root.u * 0.04 * depth
                x: root.width / 2 + modelData[2] * root.u + Math.sin(root.time * 0.6 + index) * root.u * 0.03 * depth + Math.cos(root.time * 0.3) * root.u * 0.05 * depth - width / 2
                y: root.height * 0.46 + modelData[3] * root.u + Math.cos(root.time * 0.5 + index * 1.3) * root.u * 0.03 * depth + Math.sin(root.time * 0.3) * root.u * 0.04 * depth - height / 2 + (1 - inP) * 60
                color: Qt.rgba(1, 1, 1, 0.05 + 0.04 * depth)
                border.color: Qt.rgba(1, 1, 1, 0.12 + 0.1 * depth)
                border.width: 2
                opacity: Math.min(1, inP * 1.5) * outP * (0.55 + 0.45 * Math.min(1, depth))
                scale: (0.85 + 0.15 * inP) * (0.92 + 0.08 * outP)
                z: depth * 10

                Rectangle {
                    x: glassCard.height * 0.18
                    anchors.verticalCenter: parent.verticalCenter
                    width: glassCard.height * 0.48
                    height: width
                    radius: width * 0.3
                    color: Qt.hsla((0.06 + glassCard.index * 0.13) % 1, 0.85, 0.55, 1)
                    MaterialIcon {
                        anchors.centerIn: parent
                        icon: glassCard.modelData[0]
                        iconSize: parent.width * 0.58
                        fill: 1
                        color: "#ffffff"
                    }
                }
                StyledText {
                    anchors.verticalCenter: parent.verticalCenter
                    x: glassCard.height * 0.18 + glassCard.height * 0.48 + glassCard.height * 0.16
                    text: glassCard.modelData[1]
                    font.pixelSize: glassCard.height * 0.2
                    font.weight: Font.DemiBold
                    color: "#ffffff"
                }
            }
        }
    }
}
