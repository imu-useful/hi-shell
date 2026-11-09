import QtQuick
import qs.common
import qs.common.widgets
import qs.common.shapes

// Keys "oneui", "one ui", "samsung": a silent show in a calm, rounded interface style: a big title
// at the top left and the controls reachable below it. Four scenes, each built from interface
// pieces that spring into place: app icons in squircles, quick-settings tiles that switch on and
// off, a brightness slider with switches, a stack of notification cards that get swiped away.
// All plain items; the squircles are the shell's own "square" shape.
Item {
    id: root

    required property bool revealed
    property real time: 0

    readonly property real sceneLength: 7
    readonly property real cycle: sceneLength * 4
    readonly property int sceneIndex: Math.floor((time % cycle) / sceneLength)
    readonly property real sceneTime: (time % cycle) - sceneIndex * sceneLength
    readonly property var captions: ["One UI", Translation.tr("Rounded and calm"), Translation.tr("Reach everything"), Translation.tr("Made for you")]

    readonly property real u: Math.min(width, height)
    property real baseHue: 0.6
    readonly property real hue: baseHue + Math.sin(time * 0.15) * 0.04
    readonly property color accent: Qt.hsla(hue, 0.9, 0.64, 1)
    readonly property color surface: Qt.hsla(hue, 0.18, 0.13, 1)
    readonly property color surfaceHigh: Qt.hsla(hue, 0.16, 0.19, 1)
    readonly property color textPrimary: "#f4f5f8"
    readonly property color textSecondary: "#9aa0ac"

    Component.onCompleted: {
        const h = Colors.m3primary.hslHue;
        baseHue = h >= 0 ? h : 0.6;
    }

    FrameAnimation {
        running: root.revealed
        onTriggered: root.time += frameTime
    }

    function clamp(x) {
        return Math.max(0, Math.min(1, x));
    }

    // 0 -> 1 with an overshoot
    function spring(p) {
        const x = clamp(p);
        return 1 - Math.exp(-7 * x) * Math.cos(13 * x);
    }

    // Blend two colors (either may be given as a string like "#ffffff")
    function mix(from, to, t) {
        const a = Qt.color(from), b = Qt.color(to);
        return Qt.rgba(a.r + (b.r - a.r) * t, a.g + (b.g - a.g) * t, a.b + (b.b - a.b) * t, a.a + (b.a - a.a) * t);
    }

    // How far a piece that arrives at `at` is in, and how far it has left by the end of the scene
    function enter(at) {
        return spring((sceneTime - at) / 0.6);
    }

    function leave(order) {
        return clamp((sceneLength - sceneTime - order * 0.04) / 0.3);
    }

    Rectangle {
        anchors.fill: parent
        gradient: Gradient {
            GradientStop { position: 0; color: Qt.hsla(root.hue, 0.45, 0.13, 1) }
            GradientStop { position: 1; color: "#050507" }
        }
    }

    LetterCaption {
        x: root.width * 0.08
        y: root.height * 0.09
        text: root.captions[root.sceneIndex]
        time: root.time
        sceneTime: root.sceneTime
        sceneLength: root.sceneLength
        hue: root.hue
        fontSize: Math.min(120, root.height / 9)
        saturation: 0.7
        lightness: 0.82
    }

    // ---- scene 0: app icons -----------------------------------------------------------------

    Item {
        visible: root.sceneIndex === 0
        anchors.fill: parent

        Repeater {
            model: [["call", 0.0], ["chat_bubble", 0.1], ["photo_camera", 0.2], ["music_note", 0.33], ["map", 0.45], ["mail", 0.56]]

            Item {
                id: appIcon

                required property int index
                required property var modelData
                readonly property real size: root.u * 0.17
                readonly property real inP: root.enter(0.25 + index * 0.09)
                readonly property real outP: root.leave(index)
                // One after another, each icon gets a tap: a quick squash and spring back
                readonly property real since: root.sceneTime - 2.0 - index * 0.45
                readonly property real tap: since > 0 && since < 1.2 ? Math.exp(-since * 5) * Math.sin(since * 16) * 0.14 : 0

                width: size
                height: size
                x: root.width * 0.5 + ((index % 3) - 1) * size * 1.3 - size / 2
                y: root.height * 0.64 + (Math.floor(index / 3) - 0.5) * size * 1.35 - size / 2 + Math.sin(root.time * 1.6 + index) * root.u * 0.006
                scale: (0.3 + 0.7 * inP) * (0.85 + 0.15 * outP) * (1 + tap)
                opacity: Math.min(1, inP * 1.5) * outP

                MaterialShape {
                    anchors.fill: parent
                    shape: "square"
                    animated: false
                    color: Qt.hsla((root.hue + appIcon.modelData[1]) % 1, 0.6, 0.7, 1)
                }
                MaterialIcon {
                    anchors.centerIn: parent
                    icon: appIcon.modelData[0]
                    iconSize: appIcon.size * 0.46
                    fill: 1
                    color: Qt.hsla((root.hue + appIcon.modelData[1]) % 1, 0.6, 0.18, 1)
                }
            }
        }
    }

    // ---- scene 1: quick tiles ---------------------------------------------------------------

    Item {
        visible: root.sceneIndex === 1
        anchors.fill: parent

        Repeater {
            model: [["wifi", Translation.tr("Wi-Fi"), 1.2, 4.6], ["bluetooth", "Bluetooth", 1.7, 5.0], ["flashlight_on", Translation.tr("Torch"), 2.2, 3.9], ["airplanemode_active", Translation.tr("Airplane mode"), 2.7, 5.3], ["bedtime", Translation.tr("Night mode"), 3.2, 4.3], ["location_on", Translation.tr("Location"), 3.7, 5.6]]

            Rectangle {
                id: tile

                required property int index
                required property var modelData
                readonly property bool isOn: root.sceneTime > modelData[2] && root.sceneTime < modelData[3]
                property real onness: isOn ? 1 : 0
                readonly property real inP: root.enter(0.2 + index * 0.08)
                readonly property real outP: root.leave(index)

                Behavior on onness { NumberAnimation { duration: 420; easing.type: Easing.OutBack; easing.overshoot: 1.6 } }

                width: root.u * 0.44
                height: root.u * 0.17
                radius: height / 2
                x: root.width * 0.5 + ((index % 2) - 0.5) * (width + root.u * 0.04) - width / 2 + (1 - inP) * (index % 2 ? 80 : -80)
                y: root.height * 0.64 + (Math.floor(index / 3 * 3 / 2) - 1) * (height + root.u * 0.04) - height / 2
                color: root.mix(root.surfaceHigh, root.accent, Math.min(1, tile.onness))
                scale: (0.88 + 0.12 * inP) * (0.9 + 0.1 * outP) * (1 + 0.03 * Math.max(0, tile.onness - 1) * 4)
                opacity: Math.min(1, inP * 1.5) * outP

                Row {
                    anchors.verticalCenter: parent.verticalCenter
                    x: tile.height * 0.34
                    spacing: tile.height * 0.22
                    MaterialIcon {
                        anchors.verticalCenter: parent.verticalCenter
                        icon: tile.modelData[0]
                        iconSize: tile.height * 0.42
                        fill: Math.min(1, tile.onness)
                        color: root.mix(root.textSecondary, "#ffffff", Math.min(1, tile.onness))
                        scale: 1 + 0.25 * Math.max(0, Math.min(1, tile.onness)) * (1 - Math.min(1, tile.onness) * 0.8)
                    }
                    StyledText {
                        anchors.verticalCenter: parent.verticalCenter
                        text: tile.modelData[1]
                        font.pixelSize: tile.height * 0.25
                        font.weight: Font.Medium
                        color: root.mix(root.textSecondary, "#ffffff", Math.min(1, tile.onness))
                    }
                }
            }
        }
    }

    // ---- scene 2: slider and switches ---------------------------------------------------------

    Item {
        visible: root.sceneIndex === 2
        anchors.fill: parent

        // Brightness: a fat pill that fills from the left, the value inside
        Rectangle {
            id: slider
            readonly property real inP: root.enter(0.2)
            readonly property real outP: root.leave(0)
            readonly property real value: 0.55 + 0.4 * Math.sin(Math.max(0, root.sceneTime - 0.8) * 1.1)

            width: root.u * 0.92
            height: root.u * 0.13
            radius: height / 2
            x: (root.width - width) / 2
            y: root.height * 0.36 + (1 - inP) * 60
            color: root.surfaceHigh
            clip: true
            opacity: Math.min(1, inP * 1.5) * outP
            scale: (0.9 + 0.1 * inP) * (0.92 + 0.08 * outP)

            Rectangle {
                width: Math.max(slider.height, slider.width * slider.value)
                height: parent.height
                radius: height / 2
                color: root.accent
            }
            MaterialIcon {
                x: slider.height * 0.36
                anchors.verticalCenter: parent.verticalCenter
                icon: "brightness_medium"
                iconSize: slider.height * 0.42
                fill: 1
                color: "#ffffff"
            }
            StyledText {
                anchors.right: parent.right
                anchors.rightMargin: slider.height * 0.4
                anchors.verticalCenter: parent.verticalCenter
                text: Math.round(slider.value * 100) + "%"
                font.pixelSize: slider.height * 0.34
                font.weight: Font.DemiBold
                color: "#ffffff"
            }
        }

        // Three rows with switches that flip in turn
        Repeater {
            model: [[Translation.tr("Dark mode"), 1.0, 4.8], [Translation.tr("Always on display"), 1.7, 5.4], [Translation.tr("Haptics"), 2.4, 4.0]]

            Rectangle {
                id: row

                required property int index
                required property var modelData
                readonly property real inP: root.enter(0.45 + index * 0.1)
                readonly property real outP: root.leave(index + 1)
                readonly property bool isOn: root.sceneTime > modelData[1] && root.sceneTime < modelData[2]
                property real onness: isOn ? 1 : 0

                Behavior on onness { NumberAnimation { duration: 380; easing.type: Easing.OutBack; easing.overshoot: 1.4 } }

                width: root.u * 0.92
                height: root.u * 0.1
                radius: root.u * 0.035
                x: (root.width - width) / 2
                y: root.height * 0.36 + slider.height + root.u * 0.03 + index * (height + root.u * 0.02) + (1 - inP) * 70
                color: root.surface
                opacity: Math.min(1, inP * 1.5) * outP
                scale: (0.92 + 0.08 * inP) * (0.94 + 0.06 * outP)

                StyledText {
                    anchors.verticalCenter: parent.verticalCenter
                    x: row.height * 0.4
                    text: row.modelData[0]
                    font.pixelSize: row.height * 0.3
                    color: root.textPrimary
                }

                // The switch: a pill with a round knob that springs across
                Rectangle {
                    id: track
                    width: row.height * 1.0
                    height: row.height * 0.56
                    radius: height / 2
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.right: parent.right
                    anchors.rightMargin: row.height * 0.4
                    color: root.mix("#3a3d46", root.accent, Math.min(1, row.onness))

                    Rectangle {
                        width: track.height * 0.74
                        height: width
                        radius: width / 2
                        anchors.verticalCenter: parent.verticalCenter
                        x: track.height * 0.13 + (track.width - width - track.height * 0.26) * row.onness
                        color: "#ffffff"
                    }
                }
            }
        }
    }

    // ---- scene 3: notification cards ----------------------------------------------------------

    Item {
        visible: root.sceneIndex === 3
        anchors.fill: parent

        Repeater {
            model: [["chat_bubble", Translation.tr("Messages"), Translation.tr("Hi, how's it going?"), 0.0], ["calendar_month", Translation.tr("Calendar"), Translation.tr("Coffee at 10:00"), 0.2], ["battery_full", Translation.tr("Battery"), Translation.tr("Fully charged"), 0.4], ["wb_sunny", Translation.tr("Weather"), Translation.tr("Sunny, 3°"), 0.55]]

            Rectangle {
                id: card

                required property int index
                required property var modelData
                // Position in the stack, and so how far it sits back; the front card is swiped off
                // to the right at 3.9 s, then the next one at 5.2 s, and the rest spring forward
                readonly property real swiped1: root.spring((root.sceneTime - 3.9) / 0.7)
                readonly property real swiped2: root.spring((root.sceneTime - 5.2) / 0.7)
                readonly property real depth: Math.max(0, index - (index > 0 ? swiped1 : 0) - (index > 1 ? swiped2 : 0))
                readonly property real inP: root.enter(0.3 + (3 - index) * 0.12)
                readonly property real outP: root.leave(index)
                readonly property real gone: index === 0 ? root.clamp((root.sceneTime - 3.9) / 0.7) : index === 1 ? root.clamp((root.sceneTime - 5.2) / 0.7) : 0

                width: root.u * 0.86 - depth * root.u * 0.07
                height: root.u * 0.2
                radius: root.u * 0.05
                x: (root.width - width) / 2 + (index < 2 ? (index === 0 ? swiped1 : swiped2) * root.width * 0.7 : 0)
                y: root.height * 0.6 + depth * root.u * 0.075 - height / 2 + (1 - inP) * root.height * 0.4
                color: root.mix(root.surfaceHigh, root.surface, Math.min(1, depth * 0.5))
                opacity: Math.min(1, inP * 1.5) * outP * (1 - gone * 0.9)
                z: 10 - index
                scale: 0.94 + 0.06 * outP

                MaterialShape {
                    id: cardIcon
                    width: card.height * 0.5
                    height: width
                    x: card.height * 0.28
                    anchors.verticalCenter: parent.verticalCenter
                    shape: "square"
                    animated: false
                    color: Qt.hsla((root.hue + card.index * 0.18) % 1, 0.6, 0.7, 1)
                    MaterialIcon {
                        anchors.centerIn: parent
                        icon: card.modelData[0]
                        iconSize: parent.width * 0.5
                        fill: 1
                        color: Qt.hsla((root.hue + card.index * 0.18) % 1, 0.6, 0.18, 1)
                    }
                }
                Column {
                    anchors.verticalCenter: parent.verticalCenter
                    x: card.height * 0.28 + cardIcon.width + card.height * 0.24
                    spacing: card.height * 0.05
                    StyledText {
                        text: card.modelData[1]
                        font.pixelSize: card.height * 0.2
                        font.weight: Font.DemiBold
                        color: root.textPrimary
                    }
                    StyledText {
                        text: card.modelData[2]
                        font.pixelSize: card.height * 0.19
                        color: root.textSecondary
                    }
                }
            }
        }
    }
}
