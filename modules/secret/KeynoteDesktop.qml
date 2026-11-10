import QtQuick
import qs.common
import qs.common.widgets

// A made-up hi-shell desktop for the keynote's device slide (nobody's real one): its own wallpaper
// of drifting light, a floating bar, a dock, a terminal typing hi commands, a music player whose
// spectrum dances to the beat, a notification and the control center sliding in. Laid out on a
// 1600 px wide canvas scaled to the item. `t` is the seconds since the desktop starts playing,
// `clock` a running time for the idle motion, `kick` the music's beat (0..1).
Item {
    id: desk

    property real t: 0
    property real clock: 0
    property real kick: 0

    readonly property real s: width / 1600
    readonly property color accent: "#9db4ff"
    readonly property color accent2: "#d29bff"
    readonly property color panel: Qt.rgba(0.07, 0.08, 0.13, 0.78)
    readonly property color edge: Qt.rgba(1, 1, 1, 0.09)
    readonly property color dim: "#8e93a8"

    clip: true

    function clamp(x) {
        return Math.max(0, Math.min(1, x));
    }

    // 0 -> 1 with a little overshoot, starting at `at`
    function pop(at, length) {
        const x = clamp((t - at) / (length ?? 0.6));
        return x >= 1 ? 1 : 1 - Math.exp(-6 * x) * Math.cos(9 * x);
    }

    function ease(at, length) {
        const x = clamp((t - at) / (length ?? 0.6));
        return 1 - Math.pow(1 - x, 3);
    }

    // The first characters of `text`, typed from `at` on at `speed` characters a second
    // A blinking block cursor
    readonly property string cursor: Math.floor(clock * 2.5) % 2 ? "▌" : " "

    function typed(text, at, speed) {
        return text.slice(0, Math.max(0, Math.floor((t - at) * (speed ?? 22))));
    }

    component Glass: Rectangle {
        property real shown: 1
        radius: 20
        color: desk.panel
        border.color: desk.edge
        border.width: 1
        opacity: Math.min(1, shown * 1.5)
        scale: 0.9 + 0.1 * shown
    }

    Item {
        id: canvas
        width: 1600
        height: desk.height / Math.max(0.001, desk.s)
        scale: desk.s
        transformOrigin: Item.TopLeft

        // ---- the wallpaper: a dark sky with slow blobs of light ----------------------------------

        Rectangle {
            anchors.fill: parent
            gradient: Gradient {
                GradientStop { position: 0; color: "#0a0f24" }
                GradientStop { position: 1; color: "#170b2a" }
            }
        }

        KeynoteSlides.Glow {
            width: 1300; height: 1000
            x: 100 + Math.sin(desk.clock * 0.21) * 160
            y: -300 + Math.cos(desk.clock * 0.17) * 90
            tint: "#4f6dff"
            strength: 0.75
        }

        KeynoteSlides.Glow {
            width: 1200; height: 1000
            x: 700 + Math.cos(desk.clock * 0.19) * 180
            y: 150 + Math.sin(desk.clock * 0.23) * 110
            tint: "#b65cff"
            strength: 0.6
        }

        KeynoteSlides.Glow {
            width: 900; height: 700
            x: -150 + Math.sin(desk.clock * 0.15 + 2) * 120
            y: 420 + Math.cos(desk.clock * 0.2) * 80
            tint: "#22c8c0"
            strength: 0.45
        }

        // ---- a clock widget on the wallpaper ------------------------------------------------------

        Column {
            x: 80
            y: canvas.height - 330
            spacing: 0
            opacity: desk.ease(0.8, 0.8)
            transform: Translate { y: (1 - desk.ease(0.8, 0.8)) * 30 }

            Text {
                text: "9:41"
                color: Qt.rgba(1, 1, 1, 0.92)
                font.family: Appearance.font.title
                font.pixelSize: 132
                font.weight: Font.Light
            }
            Text {
                text: new Date(2026, 8, 9).toLocaleDateString(Translation.locale, "dddd, d MMMM")
                color: Qt.rgba(1, 1, 1, 0.65)
                font.family: Appearance.font.title
                font.pixelSize: 28
                font.weight: Font.Medium
            }
        }

        // ---- the bar ------------------------------------------------------------------------------

        Glass {
            id: bar
            x: 14; y: 12
            width: canvas.width - 28
            height: 50
            radius: 25
            shown: desk.ease(0, 0.5)
            transform: Translate { y: (1 - bar.shown) * -60 }

            Row {
                anchors.left: parent.left
                anchors.leftMargin: 10
                anchors.verticalCenter: parent.verticalCenter
                spacing: 14

                Rectangle {
                    width: 34; height: 34; radius: 17
                    color: desk.accent
                    MaterialIcon { anchors.centerIn: parent; icon: "waving_hand"; iconSize: 20; fill: 1; color: "#0d1430" }
                }

                Item {
                    width: 5 * 26
                    height: 34
                    readonly property int active: 0

                    Rectangle {
                        y: 11; height: 12; radius: 6
                        width: 34
                        color: desk.accent
                        x: parent.active * 26 - 4
                    }

                    Repeater {
                        model: 5
                        Rectangle {
                            required property int index
                            x: index * 26 + 9; y: 13
                            width: 8; height: 8; radius: 4
                            visible: index !== parent.active
                            color: index < 3 ? Qt.rgba(1, 1, 1, 0.55) : Qt.rgba(1, 1, 1, 0.2)
                        }
                    }
                }
            }

            Rectangle {
                anchors.centerIn: parent
                width: 150; height: 34; radius: 17
                color: Qt.rgba(1, 1, 1, 0.08)
                Text {
                    anchors.centerIn: parent
                    text: "9:41"
                    color: "white"
                    font.family: Appearance.font.title
                    font.pixelSize: 19
                    font.weight: Font.Bold
                }
            }

            Row {
                anchors.right: parent.right
                anchors.rightMargin: 20
                anchors.verticalCenter: parent.verticalCenter
                spacing: 16

                Repeater {
                    model: ["wifi", "bluetooth", "volume_up", "battery_full"]
                    MaterialIcon { required property string modelData; icon: modelData; iconSize: 21; fill: 1; color: "#dfe3f5" }
                }

                Text {
                    text: "100%"
                    color: "#dfe3f5"
                    font.family: Appearance.font.title
                    font.pixelSize: 16
                    font.weight: Font.DemiBold
                    anchors.verticalCenter: parent.verticalCenter
                }
            }
        }

        // ---- the terminal -------------------------------------------------------------------------

        Glass {
            id: term
            x: 60; y: 100
            width: 760; height: 420
            shown: desk.pop(0.5)

            Text {
                x: 22; y: 16
                text: "~ — hi"
                color: desk.dim
                font.family: Appearance.font.title
                font.pixelSize: 15
                font.weight: Font.DemiBold
            }

            Column {
                x: 26; y: 56
                spacing: 10

                component Line: Text {
                    color: "#e6e9f5"
                    font.family: Appearance.font.mono
                    font.pixelSize: 21
                    textFormat: Text.StyledText
                }

                Line { text: `<font color="${desk.accent}">~ ❯</font> ` + desk.typed("hi wallpaper aurora.jpg", 1) + (desk.t < 2.3 ? desk.cursor : "") }
                Line { visible: desk.t > 2.3; text: `<font color="#7ee0a8">✓</font> palette made from the wallpaper` }
                Line { visible: desk.t > 2.6; text: `<font color="#7ee0a8">✓</font> bar, dock and widgets recolored` }

                Row {
                    spacing: 8
                    topPadding: 4
                    bottomPadding: 4
                    Repeater {
                        model: ["#9db4ff", "#d29bff", "#7ee0a8", "#ffd27a", "#ff8fb1", "#6fd8ff", "#c5c9dc", "#2b3150"]
                        Rectangle {
                            required property string modelData
                            required property int index
                            width: 40; height: 26; radius: 7
                            color: modelData
                            scale: desk.pop(2.9 + index * 0.125, 0.4) * (1 + 0.08 * desk.kick)
                        }
                    }
                }

                Line { visible: desk.t > 2.9; text: `<font color="${desk.accent}">~ ❯</font> ` + desk.typed('hi ask "make it pop"', 3.4) + (desk.t < 4.6 ? desk.cursor : "") }
                Line { visible: desk.t > 4.6; text: `<font color="${desk.accent2}">✦</font> done. it pops.` }
            }

        }

        // ---- the music player ---------------------------------------------------------------------

        Glass {
            id: player
            x: 860; y: 100
            width: 680; height: 240
            shown: desk.pop(1.5)
            // Steps back when the control center slides over it
            opacity: Math.min(1, shown * 1.5) * (1 - 0.6 * cc.inP)

            Rectangle {
                id: art
                x: 24; y: 24
                width: 192; height: 192; radius: 16
                gradient: Gradient {
                    orientation: Gradient.Horizontal
                    GradientStop { position: 0; color: "#5b6dff" }
                    GradientStop { position: 1; color: "#d06bff" }
                }
                scale: 1 + 0.03 * desk.kick
                MaterialIcon { anchors.centerIn: parent; icon: "music_note"; iconSize: 84; fill: 1; color: Qt.rgba(1, 1, 1, 0.9) }
            }

            Column {
                x: 244; y: 30
                spacing: 6
                Text { text: Translation.tr("Now playing"); color: desk.dim; font.family: Appearance.font.title; font.pixelSize: 16 }
                Text { text: "Midnight Drive"; color: "white"; font.family: Appearance.font.title; font.pixelSize: 32; font.weight: Font.Bold }
                Text { text: "hi-shell sessions"; color: "#c3c7da"; font.family: Appearance.font.title; font.pixelSize: 19 }
            }

            Row {
                x: 244; y: 150
                spacing: 6
                height: 50
                Repeater {
                    model: 26
                    Rectangle {
                        required property int index
                        anchors.bottom: parent.bottom
                        width: 9; radius: 4
                        height: 50 * (0.15 + 0.85 * Math.abs(Math.sin(desk.clock * 2.6 + index * 0.55) * Math.cos(desk.clock * 1.3 + index * 0.21))) * (0.55 + 0.45 * desk.kick)
                        color: Qt.rgba(0.62 + index * 0.012, 0.6, 1, 0.9)
                    }
                }
            }

            Rectangle {
                x: 244; y: 214
                width: 400; height: 6; radius: 3
                color: Qt.rgba(1, 1, 1, 0.15)
                Rectangle { width: parent.width * (0.32 + (desk.clock * 0.01) % 0.6); height: parent.height; radius: 3; color: "white" }
            }
        }

        // ---- the notification ---------------------------------------------------------------------

        Glass {
            id: toast
            readonly property real inP: desk.pop(2.5, 0.7)
            readonly property real outP: desk.ease(3.9, 0.4)
            x: canvas.width - (width + 60) * inP + outP * 500
            y: 370
            width: 420; height: 100
            radius: 24
            shown: inP * (1 - outP)

            Rectangle {
                x: 20; anchors.verticalCenter: parent.verticalCenter
                width: 56; height: 56; radius: 28
                color: "#2a2347"
                MaterialIcon { anchors.centerIn: parent; icon: "auto_awesome"; iconSize: 30; fill: 1; color: desk.accent2 }
            }

            Column {
                x: 92; anchors.verticalCenter: parent.verticalCenter
                spacing: 4
                Text { text: "Claude"; color: "white"; font.family: Appearance.font.title; font.pixelSize: 20; font.weight: Font.Bold }
                Text { text: Translation.tr("Your desktop is ready."); color: "#c3c7da"; font.family: Appearance.font.title; font.pixelSize: 17 }
            }
        }

        // ---- the control center -------------------------------------------------------------------

        Glass {
            id: cc
            readonly property real inP: desk.pop(4.2, 0.8)
            x: canvas.width - (width + 40) * inP
            y: 78
            width: 460; height: 520
            radius: 30
            shown: inP
            color: Qt.rgba(0.07, 0.08, 0.13, 0.95)

            Grid {
                x: 24; y: 24
                columns: 2
                spacing: 14

                Repeater {
                    model: [["wifi", Translation.tr("Wi-Fi"), 0], ["bluetooth", Translation.tr("Bluetooth"), 0],
                        ["dark_mode", Translation.tr("Dark mode"), 0], ["do_not_disturb_on", Translation.tr("Do not disturb"), 4.9]]

                    Rectangle {
                        required property var modelData
                        readonly property bool on: desk.t > modelData[2]
                        width: 199; height: 76; radius: 38
                        color: on ? desk.accent : Qt.rgba(1, 1, 1, 0.08)
                        Behavior on color { ColorAnimation { duration: 250 } }

                        MaterialIcon {
                            x: 20; anchors.verticalCenter: parent.verticalCenter
                            icon: parent.modelData[0]; iconSize: 26; fill: 1
                            color: parent.on ? "#0d1430" : "#dfe3f5"
                        }
                        Text {
                            x: 58; anchors.verticalCenter: parent.verticalCenter
                            width: parent.width - 70
                            text: parent.modelData[1]
                            color: parent.on ? "#0d1430" : "#dfe3f5"
                            font.family: Appearance.font.title
                            font.pixelSize: 17
                            font.weight: Font.DemiBold
                            elide: Text.ElideRight
                        }
                    }
                }
            }

            Repeater {
                model: [["volume_up", Translation.tr("Volume"), 0.45, 0.8], ["light_mode", Translation.tr("Brightness"), 0.7, 0.55]]

                Item {
                    required property var modelData
                    required property int index
                    x: 24; y: 230 + index * 110
                    width: 412; height: 90

                    Text { text: parent.modelData[1]; color: desk.dim; font.family: Appearance.font.title; font.pixelSize: 16 }
                    Rectangle {
                        y: 32; width: parent.width; height: 48; radius: 24
                        color: Qt.rgba(1, 1, 1, 0.08)
                        Rectangle {
                            readonly property var m: parent.parent.modelData
                            width: parent.width * (m[2] + (m[3] - m[2]) * desk.ease(5 + parent.parent.index * 0.5, 0.8))
                            height: parent.height; radius: 24
                            color: desk.accent
                            MaterialIcon { x: 16; anchors.verticalCenter: parent.verticalCenter; icon: parent.m[0]; iconSize: 24; fill: 1; color: "#0d1430" }
                        }
                    }
                }
            }
        }

        // ---- the dock -----------------------------------------------------------------------------

        Glass {
            id: dock
            readonly property real rise: desk.pop(0.2, 0.7)
            anchors.horizontalCenter: parent.horizontalCenter
            y: canvas.height - 100 + (1 - rise) * 140
            width: dockRow.width + 28
            height: 84
            radius: 28
            shown: 1

            Row {
                id: dockRow
                anchors.centerIn: parent
                spacing: 12

                Repeater {
                    model: [["terminal", "#3b4266"], ["folder", "#3f7cff"], ["language", "#20b5a8"], ["music_note", "#c04df0"],
                        ["chat", "#ff8a3d"], ["auto_awesome", "#7b5cff"], ["settings", "#5a6078"]]

                    Rectangle {
                        required property var modelData
                        required property int index
                        width: 60; height: 60; radius: 17
                        color: modelData[1]
                        // The music app bounces to the beat
                        transform: Translate { y: index === 3 ? -10 * desk.kick : 0 }
                        MaterialIcon { anchors.centerIn: parent; icon: parent.modelData[0]; iconSize: 32; fill: 1; color: "white" }
                        Rectangle {
                            visible: index === 0 || index === 3
                            anchors.horizontalCenter: parent.horizontalCenter
                            anchors.top: parent.bottom
                            anchors.topMargin: 4
                            width: 6; height: 6; radius: 3
                            color: "white"
                        }
                    }
                }
            }
        }
    }
}
