import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import Quickshell
import Quickshell.Wayland

// The Wait Mode cover of one screen: a full-screen overlay that takes the keyboard and the
// pointer. In bypass (see shell.qml) it's invisible, takes no input and gives the keyboard
// back, so automated tests can see and click what's underneath.
PanelWindow {
    id: win

    required property var modelData
    required property var control

    readonly property real unit: Math.min(width, height)

    screen: modelData
    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    // An empty region takes no input at all.
    mask: control.bypass ? noInput : null
    Region { id: noInput }

    WlrLayershell.namespace: "hi-wait-mode"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: control.bypass ? WlrKeyboardFocus.None : WlrKeyboardFocus.Exclusive

    // No dimming, locking or sleeping while it's on.
    IdleInhibitor {
        window: win
        enabled: true
    }

    function time(seconds) {
        const s = Math.max(0, Math.floor(seconds));
        return `${Math.floor(s / 60)}:${String(s % 60).padStart(2, "0")}`;
    }

    FocusScope {
        anchors.fill: parent
        focus: true

        Keys.onPressed: event => {
            // Esc three times (within a few seconds) ends it; everything else goes nowhere.
            if (event.key === Qt.Key_Escape && !event.isAutoRepeat)
                win.control.pressEsc();
            event.accepted = true;
        }

        // Everything the person sees.
        Rectangle {
            anchors.fill: parent
            color: Theme.background
            opacity: win.control.bypass ? 0 : 1
            Behavior on opacity { NumberAnimation { duration: 120 } }

            // The wallpaper, blurred and dimmed.
            Image {
                id: wall
                anchors.fill: parent
                visible: false
                source: Theme.wallpaper ? `file://${Theme.wallpaper}` : ""
                asynchronous: true
                fillMode: Image.PreserveAspectCrop
                sourceSize: Qt.size(win.width / 2, win.height / 2)
            }
            MultiEffect {
                anchors.fill: parent
                visible: Theme.wallpaper !== ""
                source: wall
                blurEnabled: true
                blur: 1
                blurMax: 64
                brightness: -0.3
                saturation: -0.15
            }

            Loader {
                anchors.fill: parent
                sourceComponent: win.control.hasMusic ? music : frame
            }

            // Esc x 3: three dots that fill up.
            ColumnLayout {
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.bottom: parent.bottom
                anchors.bottomMargin: win.unit * 0.05
                spacing: 10

                Row {
                    Layout.alignment: Qt.AlignHCenter
                    spacing: 10
                    Repeater {
                        model: 3
                        Rectangle {
                            required property int index
                            width: 12
                            height: 12
                            radius: 6
                            color: index < win.control.escapes ? Theme.primary : "transparent"
                            border.width: 2
                            border.color: index < win.control.escapes ? Theme.primary : Theme.outline
                            Behavior on color { ColorAnimation { duration: 120 } }
                        }
                    }
                }
                Text {
                    Layout.alignment: Qt.AlignHCenter
                    text: Theme.tr("Press Esc three times to exit", "Нажмите Esc три раза, чтобы выйти")
                    color: Theme.muted
                    font.pixelSize: Math.max(14, win.unit * 0.018)
                }
            }
        }
    }

    // --- Music: the cover, the title and artist, the progress and the buttons, the queue ---
    Component {
        id: music

        Item {
            readonly property var player: win.control.player
            readonly property real cover: win.unit * 0.42
            readonly property bool hasQueue: win.control.queue.length > 0

            RowLayout {
                anchors.centerIn: parent
                spacing: win.unit * 0.08

                ColumnLayout {
                    Layout.alignment: Qt.AlignVCenter
                    spacing: win.unit * 0.025

                    Text {
                        Layout.alignment: Qt.AlignHCenter
                        text: Theme.tr("Wait Mode", "Режим ожидания")
                        color: Theme.primary
                        font.pixelSize: Math.max(14, win.unit * 0.02)
                        font.weight: Font.Medium
                        font.letterSpacing: 2
                    }
                    RoundedImage {
                        Layout.alignment: Qt.AlignHCenter
                        implicitWidth: cover
                        implicitHeight: cover
                        radius: cover * 0.08
                        source: player?.trackArtUrl ?? ""
                    }
                    Text {
                        Layout.alignment: Qt.AlignHCenter
                        Layout.maximumWidth: hasQueue ? cover * 1.2 : win.width * 0.8
                        text: player?.trackTitle ?? ""
                        color: Theme.text
                        elide: Text.ElideRight
                        font.pixelSize: win.unit * 0.045
                        font.weight: Font.DemiBold
                    }
                    Text {
                        Layout.alignment: Qt.AlignHCenter
                        Layout.maximumWidth: hasQueue ? cover * 1.2 : win.width * 0.8
                        text: player?.trackArtist ?? ""
                        color: Theme.muted
                        elide: Text.ElideRight
                        font.pixelSize: win.unit * 0.028
                    }

                    // The song's bar: where it is, and how long it is.
                    RowLayout {
                        Layout.alignment: Qt.AlignHCenter
                        Layout.preferredWidth: cover * 1.1
                        spacing: 12
                        Text {
                            text: win.time(player?.position ?? 0)
                            color: Theme.muted
                            font.pixelSize: win.unit * 0.02
                            font.features: { "tnum": 1 }
                        }
                        Rectangle {
                            Layout.fillWidth: true
                            implicitHeight: Math.max(8, win.unit * 0.01)
                            radius: height / 2
                            color: Qt.alpha(Theme.text, 0.22)
                            Rectangle {
                                width: parent.width * Math.min(1, (player?.position ?? 0) / Math.max(1, player?.length ?? 1))
                                height: parent.height
                                radius: height / 2
                                color: Theme.primary
                            }
                        }
                        Text {
                            text: win.time(player?.length ?? 0)
                            color: Theme.muted
                            font.pixelSize: win.unit * 0.02
                            font.features: { "tnum": 1 }
                        }
                    }

                    // The player's buttons (the only ones the cover has): shuffle, back, forward, repeat.
                    RowLayout {
                        Layout.alignment: Qt.AlignHCenter
                        spacing: win.unit * 0.03

                        Repeater {
                            model: [
                                { kind: "shuffle", shown: win.control.shuffleSupported },
                                { kind: "previous", shown: win.control.canPrevious },
                                { kind: "playpause", shown: win.control.canTogglePlaying },
                                { kind: "next", shown: win.control.canNext },
                                { kind: "repeat", shown: win.control.loopSupported }
                            ]

                            Rectangle {
                                id: btn
                                required property var modelData
                                // Shuffle and repeat show whether they're on; back and forward are plain buttons.
                                readonly property bool on: modelData.kind === "shuffle" ? win.control.shuffle
                                    : modelData.kind === "repeat" ? !win.control.loopOff : false

                                // Play / pause is the main button: bigger, always in the accent color.
                                readonly property bool main: modelData.kind === "playpause"

                                visible: modelData.shown
                                implicitWidth: win.unit * (main ? 0.095 : 0.075)
                                implicitHeight: implicitWidth
                                radius: width / 2
                                color: on || main ? Theme.primary : (mouse.containsMouse ? Qt.alpha(Theme.text, 0.18) : Theme.surface)
                                Behavior on color { ColorAnimation { duration: 120 } }

                                Text {
                                    anchors.centerIn: parent
                                    text: btn.modelData.kind === "shuffle" ? "shuffle"
                                        : btn.modelData.kind === "playpause" ? (win.control.playing ? "pause" : "play_arrow")
                                        : btn.modelData.kind === "previous" ? "skip_previous"
                                        : btn.modelData.kind === "next" ? "skip_next"
                                        : (win.control.loopTrack ? "repeat_one" : "repeat")
                                    font.family: "Material Symbols Rounded"
                                    font.pixelSize: win.unit * (btn.main ? 0.052 : 0.04)
                                    color: btn.on || btn.main ? Theme.onPrimary : Theme.text
                                }
                                MouseArea {
                                    id: mouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        const k = btn.modelData.kind;
                                        if (k === "shuffle")
                                            win.control.toggleShuffle();
                                        else if (k === "playpause")
                                            win.control.togglePlaying();
                                        else if (k === "previous")
                                            win.control.previous();
                                        else if (k === "next")
                                            win.control.next();
                                        else
                                            win.control.cycleLoop();
                                    }
                                }
                            }
                        }
                    }
                }

                // What plays next (Spotify; needs hi-shell's sign-in).
                ColumnLayout {
                    visible: hasQueue
                    Layout.alignment: Qt.AlignVCenter
                    Layout.preferredWidth: win.unit * 0.5
                    spacing: win.unit * 0.012

                    Text {
                        text: Theme.tr("Up next", "Дальше")
                        color: Theme.primary
                        font.pixelSize: Math.max(14, win.unit * 0.022)
                        font.weight: Font.Medium
                        font.letterSpacing: 2
                    }
                    Repeater {
                        model: win.control.queue

                        RowLayout {
                            required property var modelData
                            Layout.fillWidth: true
                            spacing: 14

                            RoundedImage {
                                implicitWidth: win.unit * 0.07
                                implicitHeight: win.unit * 0.07
                                radius: win.unit * 0.012
                                source: modelData.art ?? ""
                            }
                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 0
                                Text {
                                    Layout.fillWidth: true
                                    text: modelData.name
                                    color: Theme.text
                                    elide: Text.ElideRight
                                    font.pixelSize: win.unit * 0.026
                                    font.weight: Font.Medium
                                }
                                Text {
                                    Layout.fillWidth: true
                                    text: modelData.artists
                                    color: Theme.muted
                                    elide: Text.ElideRight
                                    font.pixelSize: win.unit * 0.02
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    // --- No music: the wallpaper in a frame, with the name of the mode ---
    Component {
        id: frame

        Item {
            ColumnLayout {
                anchors.centerIn: parent
                spacing: win.unit * 0.04

                RoundedImage {
                    id: picture
                    Layout.alignment: Qt.AlignHCenter
                    implicitWidth: win.unit * 0.5
                    implicitHeight: win.unit * 0.5
                    radius: win.unit * 0.12
                    source: Theme.wallpaper ? `file://${Theme.wallpaper}` : ""

                    // A thin outline, so the frame shows against a dark wallpaper.
                    Rectangle {
                        anchors.fill: parent
                        radius: picture.radius
                        color: "transparent"
                        border.width: 3
                        border.color: Qt.alpha(Theme.primary, 0.6)
                    }
                }
                Text {
                    Layout.alignment: Qt.AlignHCenter
                    text: Theme.tr("Wait Mode", "Режим ожидания")
                    color: Theme.text
                    font.pixelSize: win.unit * 0.06
                    font.weight: Font.DemiBold
                }
            }
        }
    }
}
