import QtQuick
import qs.common
import qs.common.widgets

// Keys "aero", "frutiger" and "frutiger aero": a silent show in the glossy, bright style of the
// late 2000s: blue sky, hills and soap bubbles (aero.frag), glass panels with a gloss on top,
// jelly buttons. Four scenes: a glowing orb, a glass window, a loading bar with a busy ring, a few
// gadgets (a clock with the real time, the weather, a volume slider).
Item {
    id: root

    required property bool revealed
    property real time: 0

    readonly property real sceneLength: 7
    readonly property real cycle: sceneLength * 4
    readonly property int sceneIndex: Math.floor((time % cycle) / sceneLength)
    readonly property real sceneTime: (time % cycle) - sceneIndex * sceneLength
    readonly property var captions: ["Frutiger Aero", Translation.tr("Glass and gloss"), Translation.tr("Almost there"), Translation.tr("Made for you")]
    // How big the bubbles are in each scene, so the busier scenes keep them out of the way
    readonly property var bubbleScale: [1.0, 0.7, 0.55, 0.9]

    readonly property real u: Math.min(width, height)
    readonly property color ink: "#0b2a55"
    readonly property color glassTop: Qt.rgba(1, 1, 1, 0.62)
    readonly property color glassBottom: Qt.rgba(1, 1, 1, 0.22)

    property real bubbleMix: 1
    property vector4d b0; property vector4d b1; property vector4d b2; property vector4d b3
    property vector4d b4; property vector4d b5; property vector4d b6; property vector4d b7
    property string clockText: ""
    property real hours: 0
    property real minutes: 0
    property real seconds: 0

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

    function layoutBubbles() {
        const w = width, h = height;
        if (w <= 0)
            return;
        const t = time;
        // The size follows the scene smoothly: it glides to the next scene's in its last second
        const mix = clamp((sceneTime - (sceneLength - 1)) / 1);
        const m = bubbleScale[sceneIndex] + (bubbleScale[(sceneIndex + 1) % 4] - bubbleScale[sceneIndex]) * mix;
        const list = [];
        for (let k = 0; k < 8; k++) {
            const speed = 0.05 + (k % 4) * 0.012;
            list.push(Qt.vector4d(w * (0.08 + ((k * 0.382) % 1) * 0.84) + Math.sin(t * 0.8 + k) * u * 0.03,
                                  h * (1.1 - ((t * speed + k * 0.125) % 1.25)),
                                  u * (0.035 + 0.05 * ((k * 7) % 5) / 4) * m, 0));
        }
        b0 = list[0]; b1 = list[1]; b2 = list[2]; b3 = list[3]; b4 = list[4]; b5 = list[5]; b6 = list[6]; b7 = list[7];
    }

    function refreshClock() {
        const now = new Date();
        hours = now.getHours() % 12 + now.getMinutes() / 60;
        minutes = now.getMinutes() + now.getSeconds() / 60;
        seconds = now.getSeconds();
        clockText = Qt.formatTime(now, "HH:mm");
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
        onTriggered: {
            root.time += frameTime;
            root.layoutBubbles();
        }
    }

    ShaderEffect {
        anchors.fill: parent
        property vector2d res: Qt.vector2d(width, height)
        property real time: root.time
        property vector4d b0: root.b0
        property vector4d b1: root.b1
        property vector4d b2: root.b2
        property vector4d b3: root.b3
        property vector4d b4: root.b4
        property vector4d b5: root.b5
        property vector4d b6: root.b6
        property vector4d b7: root.b7
        fragmentShader: Qt.resolvedUrl("aero.frag.qsb")
    }

    LetterCaption {
        anchors.horizontalCenter: parent.horizontalCenter
        y: root.height * 0.07
        text: root.captions[root.sceneIndex]
        time: root.time
        sceneTime: root.sceneTime
        sceneLength: root.sceneLength
        hue: 0.56
        fontSize: Math.min(110, root.height / 10)
        saturation: 0.1
        lightness: 0.97
        outlineColor: Qt.rgba(0.02, 0.2, 0.5, 0.9)
        z: 20
    }

    // ---- shared pieces -------------------------------------------------------------------------

    // A pane of glass: a milky gradient, a bright edge, a gloss over the top half
    component Glass: Rectangle {
        property real gloss: 0.5
        gradient: Gradient {
            GradientStop { position: 0; color: root.glassTop }
            GradientStop { position: 1; color: root.glassBottom }
        }
        border.color: Qt.rgba(1, 1, 1, 0.85)
        border.width: 2
        Rectangle {
            x: 3
            y: 3
            width: parent.width - 6
            height: parent.height * parent.gloss
            radius: Math.max(1, parent.radius - 3)
            gradient: Gradient {
                GradientStop { position: 0; color: Qt.rgba(1, 1, 1, 0.55) }
                GradientStop { position: 1; color: Qt.rgba(1, 1, 1, 0.04) }
            }
        }
    }

    // A jelly button: a coloured body, a darker lower half, a shine on the top
    component Jelly: Rectangle {
        property color topColor: "#5cc8ff"
        property color bottomColor: "#0a6fd6"
        property alias label: text.text
        property alias icon: ico.icon
        radius: height / 2
        gradient: Gradient {
            GradientStop { position: 0; color: topColor }
            GradientStop { position: 1; color: bottomColor }
        }
        border.color: Qt.rgba(1, 1, 1, 0.9)
        border.width: 2
        Rectangle {
            x: parent.width * 0.06
            y: parent.height * 0.07
            width: parent.width * 0.88
            height: parent.height * 0.46
            radius: height / 2
            gradient: Gradient {
                GradientStop { position: 0; color: Qt.rgba(1, 1, 1, 0.75) }
                GradientStop { position: 1; color: Qt.rgba(1, 1, 1, 0.08) }
            }
        }
        StyledText {
            id: text
            anchors.centerIn: parent
            font.pixelSize: parent.height * 0.4
            font.weight: Font.Bold
            color: "white"
            style: Text.Outline
            styleColor: Qt.rgba(0, 0.1, 0.35, 0.55)
        }
        MaterialIcon {
            id: ico
            anchors.centerIn: parent
            iconSize: parent.height * 0.55
            fill: 1
            color: "white"
        }
    }

    // ---- scene 0: the orb ----------------------------------------------------------------------

    Item {
        visible: root.sceneIndex === 0
        anchors.fill: parent

        Item {
            id: orb
            readonly property real inP: root.enter(0.2)
            readonly property real outP: root.leave(0)
            readonly property real size: root.u * 0.3

            width: size
            height: size
            x: root.width / 2 - width / 2
            y: root.height * 0.5 - height / 2 + (1 - inP) * root.u * 0.25
            scale: (0.4 + 0.6 * inP) * (0.9 + 0.1 * outP) * (1 + 0.035 * Math.sin(root.time * 2.2))
            opacity: Math.min(1, inP * 1.5) * outP

            Rectangle {
                anchors.fill: parent
                radius: width / 2
                gradient: Gradient {
                    GradientStop { position: 0; color: "#9ff0ff" }
                    GradientStop { position: 1; color: "#0a4fb3" }
                }
                border.color: Qt.rgba(1, 1, 1, 0.9)
                border.width: 4
            }
            Rectangle {
                anchors.fill: parent
                anchors.margins: orb.size * 0.07
                radius: width / 2
                gradient: Gradient {
                    GradientStop { position: 0; color: "#27b0ff" }
                    GradientStop { position: 0.55; color: "#0a63d8" }
                    GradientStop { position: 1; color: "#06b6a8" }
                }
            }
            Rectangle {
                x: orb.size * 0.14
                y: orb.size * 0.07
                width: orb.size * 0.72
                height: orb.size * 0.46
                radius: height / 2
                gradient: Gradient {
                    GradientStop { position: 0; color: Qt.rgba(1, 1, 1, 0.9) }
                    GradientStop { position: 1; color: Qt.rgba(1, 1, 1, 0.05) }
                }
            }
            StyledText {
                anchors.centerIn: parent
                anchors.verticalCenterOffset: orb.size * 0.06
                text: "hi"
                font.family: Appearance.font.title
                font.pixelSize: orb.size * 0.42
                font.weight: Font.Black
                color: "white"
                style: Text.Outline
                styleColor: Qt.rgba(0, 0.1, 0.35, 0.6)
            }
        }

        // Rings leaving the orb
        Repeater {
            model: 2
            Rectangle {
                required property int index
                readonly property real age: ((root.time * 0.5 + index * 0.5) % 1)
                width: orb.size * (1 + age * 0.9)
                height: width
                radius: width / 2
                x: root.width / 2 - width / 2
                y: orb.y + orb.height / 2 - height / 2
                color: "transparent"
                border.color: Qt.rgba(1, 1, 1, 0.8 * (1 - age))
                border.width: 3
                opacity: orb.opacity
            }
        }
    }

    // ---- scene 1: the window -------------------------------------------------------------------

    Item {
        visible: root.sceneIndex === 1
        anchors.fill: parent

        Glass {
            id: win
            readonly property real inP: root.enter(0.2)
            readonly property real outP: root.leave(0)

            width: root.u * 1.05
            height: root.u * 0.58
            radius: root.u * 0.03
            x: root.width / 2 - width / 2 + Math.sin(root.time * 0.7) * root.u * 0.01
            y: root.height * 0.55 - height / 2 + (1 - inP) * root.u * 0.2 + Math.cos(root.time * 0.6) * root.u * 0.008
            scale: (0.8 + 0.2 * inP) * (0.92 + 0.08 * outP)
            opacity: Math.min(1, inP * 1.5) * outP
            gloss: 0.32

            // Title bar
            StyledText {
                x: win.height * 0.07
                y: win.height * 0.025
                text: "hi-shell"
                font.pixelSize: win.height * 0.05
                font.weight: Font.DemiBold
                color: root.ink
            }
            Row {
                anchors.right: parent.right
                anchors.rightMargin: win.height * 0.04
                y: 0
                spacing: -2
                Jelly { width: win.height * 0.1; height: win.height * 0.058; topColor: "#a7dcff"; bottomColor: "#3b8fd9"; icon: "remove" }
                Jelly { width: win.height * 0.1; height: win.height * 0.058; topColor: "#a7dcff"; bottomColor: "#3b8fd9"; icon: "crop_square" }
                Jelly { width: win.height * 0.14; height: win.height * 0.058; topColor: "#ff9a8a"; bottomColor: "#d1260f"; icon: "close" }
            }

            // Sidebar
            Repeater {
                model: [["home", Translation.tr("Home")], ["photo_library", Translation.tr("Pictures")], ["music_note", Translation.tr("Music")], ["settings", Translation.tr("Settings")]]
                Rectangle {
                    id: side
                    required property int index
                    required property var modelData
                    readonly property real inP: root.enter(0.5 + index * 0.12)
                    readonly property bool selected: Math.floor(root.sceneTime * 0.9) % 4 === index
                    x: win.height * 0.05 + (1 - inP) * -40
                    y: win.height * 0.14 + index * win.height * 0.14
                    width: win.width * 0.27
                    height: win.height * 0.115
                    radius: height * 0.25
                    color: selected ? Qt.rgba(1, 1, 1, 0.6) : "transparent"
                    border.color: selected ? Qt.rgba(1, 1, 1, 0.95) : "transparent"
                    border.width: 2
                    opacity: Math.min(1, inP * 1.5)
                    Behavior on color { ColorAnimation { duration: 200 } }
                    MaterialIcon {
                        x: parent.height * 0.25
                        anchors.verticalCenter: parent.verticalCenter
                        icon: side.modelData[0]
                        iconSize: parent.height * 0.55
                        fill: 1
                        color: "#1a73d9"
                    }
                    StyledText {
                        x: parent.height * 1.05
                        anchors.verticalCenter: parent.verticalCenter
                        text: side.modelData[1]
                        font.pixelSize: parent.height * 0.42
                        color: root.ink
                    }
                }
            }

            // Content: a headline, two lines of text, the buttons
            Column {
                x: win.width * 0.34
                y: win.height * 0.16
                width: win.width * 0.6
                spacing: win.height * 0.03
                opacity: Math.min(1, root.enter(0.9) * 1.5)
                StyledText {
                    text: Translation.tr("Welcome back")
                    font.pixelSize: win.height * 0.1
                    font.weight: Font.Bold
                    color: "#0a4fb3"
                }
                StyledText {
                    width: parent.width
                    text: Translation.tr("Everything is shiny and where you left it.")
                    wrapMode: Text.Wrap
                    elide: Text.ElideNone
                    font.pixelSize: win.height * 0.055
                    color: root.ink
                }
            }
            Row {
                anchors.right: parent.right
                anchors.rightMargin: win.height * 0.06
                anchors.bottom: parent.bottom
                anchors.bottomMargin: win.height * 0.07
                spacing: win.height * 0.04
                opacity: Math.min(1, root.enter(1.2) * 1.5)
                Jelly { width: win.height * 0.3; height: win.height * 0.11; topColor: "#d9e8f7"; bottomColor: "#8fb4dc"; label: Translation.tr("Cancel") }
                Jelly {
                    width: win.height * 0.3
                    height: win.height * 0.11
                    topColor: "#7fe98f"
                    bottomColor: "#12a53a"
                    label: "OK"
                    scale: 1 + 0.04 * Math.sin(root.time * 3.5)
                }
            }
        }
    }

    // ---- scene 2: loading ----------------------------------------------------------------------

    Item {
        visible: root.sceneIndex === 2
        anchors.fill: parent

        readonly property real inP: root.enter(0.2)
        readonly property real outP: root.leave(0)
        readonly property real progress: 1 - Math.pow(1 - root.clamp((root.sceneTime - 0.6) / 5), 3)

        // The busy ring: a circle of dots that fade out behind the leading one
        Item {
            x: root.width / 2
            y: root.height * 0.38
            opacity: Math.min(1, parent.inP * 1.5) * parent.outP
            Repeater {
                model: 10
                Rectangle {
                    required property int index
                    readonly property real phase: ((root.time * 1.6 - index / 10) % 1 + 1) % 1
                    readonly property real a: index / 10 * Math.PI * 2
                    width: root.u * 0.03 * (1 - 0.5 * phase)
                    height: width
                    radius: width / 2
                    x: Math.cos(a) * root.u * 0.08 - width / 2
                    y: Math.sin(a) * root.u * 0.08 - height / 2
                    color: "white"
                    border.color: Qt.rgba(0.05, 0.4, 0.85, 0.7)
                    border.width: 2
                    opacity: 1 - phase * 0.85
                }
            }
        }

        // The bar: a glass tube with a green jelly fill and a shine sliding along it
        Glass {
            id: tube
            width: root.u * 1.0
            height: root.u * 0.075
            radius: height / 2
            x: root.width / 2 - width / 2
            y: root.height * 0.55
            gloss: 0.5
            opacity: Math.min(1, parent.inP * 1.5) * parent.outP
            scale: (0.9 + 0.1 * parent.inP)
            clip: true

            Rectangle {
                x: 4
                y: 4
                width: Math.max(height, (tube.width - 8) * parent.parent.progress)
                height: tube.height - 8
                radius: height / 2
                gradient: Gradient {
                    GradientStop { position: 0; color: "#8bf29a" }
                    GradientStop { position: 0.5; color: "#26c24a" }
                    GradientStop { position: 1; color: "#0f9a35" }
                }
                Rectangle {
                    x: parent.width * 0.04
                    y: parent.height * 0.08
                    width: parent.width * 0.92
                    height: parent.height * 0.42
                    radius: height / 2
                    gradient: Gradient {
                        GradientStop { position: 0; color: Qt.rgba(1, 1, 1, 0.7) }
                        GradientStop { position: 1; color: Qt.rgba(1, 1, 1, 0.05) }
                    }
                }
                // A shine that keeps running along the fill
                Rectangle {
                    x: ((root.time * 0.6) % 1) * parent.width * 1.3 - parent.width * 0.15
                    width: parent.height * 1.2
                    height: parent.height
                    rotation: 20
                    color: Qt.rgba(1, 1, 1, 0.35)
                }
            }
        }

        StyledText {
            anchors.horizontalCenter: parent.horizontalCenter
            y: root.height * 0.55 + tube.height + root.u * 0.025
            text: Math.round(parent.progress * 100) + "%  ·  " + Translation.tr("Please wait…")
            font.pixelSize: root.u * 0.04
            font.weight: Font.DemiBold
            color: "white"
            style: Text.Outline
            styleColor: Qt.rgba(0.02, 0.2, 0.5, 0.8)
            opacity: Math.min(1, parent.inP * 1.5) * parent.outP
        }
    }

    // ---- scene 3: gadgets ----------------------------------------------------------------------

    Item {
        visible: root.sceneIndex === 3
        anchors.fill: parent

        // The clock, with the real time
        Glass {
            id: clock
            readonly property real inP: root.enter(0.2)
            readonly property real outP: root.leave(0)
            width: root.u * 0.4
            height: width
            radius: width / 2
            x: root.width / 2 - root.u * 0.6 - width / 2
            y: root.height * 0.56 - height / 2 + (1 - inP) * root.u * 0.2
            scale: (0.7 + 0.3 * inP) * (0.92 + 0.08 * outP)
            opacity: Math.min(1, inP * 1.5) * outP
            gloss: 0.5

            Repeater {
                model: 12
                Rectangle {
                    id: tick
                    required property int index
                    width: index % 3 === 0 ? clock.width * 0.025 : clock.width * 0.012
                    height: index % 3 === 0 ? clock.width * 0.07 : clock.width * 0.045
                    radius: width / 2
                    color: root.ink
                    x: clock.width / 2 - width / 2
                    y: clock.width * 0.05
                    transform: Rotation {
                        origin.x: tick.width / 2
                        origin.y: clock.width * 0.45
                        angle: tick.index * 30
                    }
                }
            }
            // Hour, minute, second
            Rectangle {
                id: hourHand
                x: clock.width / 2 - width / 2
                y: clock.width / 2 - height
                width: clock.width * 0.035
                height: clock.width * 0.24
                radius: width / 2
                color: root.ink
                transform: Rotation { origin.x: hourHand.width / 2; origin.y: hourHand.height; angle: root.hours * 30 }
            }
            Rectangle {
                id: minuteHand
                x: clock.width / 2 - width / 2
                y: clock.width / 2 - height
                width: clock.width * 0.025
                height: clock.width * 0.34
                radius: width / 2
                color: root.ink
                transform: Rotation { origin.x: minuteHand.width / 2; origin.y: minuteHand.height; angle: root.minutes * 6 }
            }
            Rectangle {
                id: secondHand
                x: clock.width / 2 - width / 2
                y: clock.width / 2 - height
                width: clock.width * 0.012
                height: clock.width * 0.38
                radius: width / 2
                color: "#e0301e"
                transform: Rotation { origin.x: secondHand.width / 2; origin.y: secondHand.height; angle: root.seconds * 6 }
            }
            Rectangle {
                anchors.centerIn: parent
                width: clock.width * 0.06
                height: width
                radius: width / 2
                color: "#e0301e"
            }
        }

        // The weather bubble
        Glass {
            id: weather
            readonly property real inP: root.enter(0.35)
            readonly property real outP: root.leave(1)
            width: root.u * 0.3
            height: width
            radius: width / 2
            x: root.width / 2 - width / 2
            y: root.height * 0.56 - height / 2 + (1 - inP) * root.u * 0.2 + Math.sin(root.time * 1.2) * root.u * 0.01
            scale: (0.7 + 0.3 * inP) * (0.92 + 0.08 * outP)
            opacity: Math.min(1, inP * 1.5) * outP
            gloss: 0.5
            MaterialIcon {
                anchors.horizontalCenter: parent.horizontalCenter
                y: weather.height * 0.17
                icon: "wb_sunny"
                iconSize: weather.height * 0.34
                fill: 1
                color: "#ffb21a"
                rotation: root.time * 25
            }
            StyledText {
                anchors.horizontalCenter: parent.horizontalCenter
                y: weather.height * 0.55
                text: "21°"
                font.family: Appearance.font.title
                font.pixelSize: weather.height * 0.26
                font.weight: Font.Black
                color: root.ink
            }
        }

        // The volume slider
        Glass {
            id: volume
            readonly property real inP: root.enter(0.5)
            readonly property real outP: root.leave(2)
            readonly property real level: 0.5 + 0.4 * Math.sin(root.time * 1.3)
            width: root.u * 0.13
            height: root.u * 0.4
            radius: width / 2
            x: root.width / 2 + root.u * 0.6 - width / 2
            y: root.height * 0.56 - height / 2 + (1 - inP) * root.u * 0.2
            scale: (0.7 + 0.3 * inP) * (0.92 + 0.08 * outP)
            opacity: Math.min(1, inP * 1.5) * outP
            gloss: 0.3
            clip: true

            Rectangle {
                anchors.bottom: parent.bottom
                anchors.bottomMargin: 4
                x: 4
                width: volume.width - 8
                height: Math.max(width, (volume.height - 8) * volume.level)
                radius: width / 2
                gradient: Gradient {
                    GradientStop { position: 0; color: "#8fe0ff" }
                    GradientStop { position: 1; color: "#0a6fd6" }
                }
            }
            MaterialIcon {
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.bottom: parent.bottom
                anchors.bottomMargin: volume.width * 0.2
                icon: "volume_up"
                iconSize: volume.width * 0.5
                fill: 1
                color: "white"
            }
        }
    }
}
