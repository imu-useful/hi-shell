import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.common
import qs.common.widgets

// Startup: a black screen, then "Welcome back!" (the letters rise in one after another), then the
// black and the text fade away together, and the shell's own intro animation plays underneath.
Scope {
    id: root

    readonly property string text: "Welcome back!"
    readonly property int letterDelay: 55
    readonly property int blackHold: 500 // black alone, before the text
    readonly property int textHold: 1500 // text fully shown, before everything fades
    readonly property int fadeDuration: 700

    // One of five ways for the letters to come in, picked at random on each start:
    // 0 rise from below, 1 drop from above, 2 pop (scale, springy), 3 slide in from alternating
    // sides, 4 spin.
    // Each also has its own place on the screen, always centered horizontally: 0 bottom, 1 top,
    // 2 middle, 3 middle with the letters stacked vertically, 4 middle.
    readonly property int styles: 5
    readonly property bool vertical: style === 3
    readonly property int edgeMargin: 120
    property int style: Math.floor(Math.random() * styles)

    property bool lettersIn: false
    // 0..1, the exit fade of the black and the text
    property real outro: 0
    property bool done: false

    Component.onCompleted: {
        // Without animations (or in Focus Mode) there's no greeting; don't hold the intro.
        if (Appearance.anim.speed <= 0) {
            done = true;
            return;
        }
        ShellState.greeting = true;
        textTimer.start();
    }

    Timer {
        id: textTimer
        interval: root.blackHold
        onTriggered: {
            root.lettersIn = true;
            fadeTimer.start();
        }
    }

    Timer {
        id: fadeTimer
        interval: root.text.length * root.letterDelay + 400 + root.textHold
        onTriggered: {
            // The desktop starts coming in as the black fades.
            ShellState.greeting = false;
            fadeOut.start();
        }
    }

    NumberAnimation {
        id: fadeOut
        target: root
        property: "outro"
        to: 1
        duration: root.fadeDuration
        easing.type: Easing.InOutCubic
        onFinished: root.done = true
    }

    LazyLoader {
        active: !root.done

        Variants {
            model: Quickshell.screens

            PanelWindow {
                id: window

                required property ShellScreen modelData

                screen: modelData
                anchors.top: true
                anchors.bottom: true
                anchors.left: true
                anchors.right: true
                exclusionMode: ExclusionMode.Ignore
                mask: Region {}
                color: "transparent"

                WlrLayershell.namespace: "hi-shell-greeting"
                WlrLayershell.layer: WlrLayer.Overlay

                Rectangle {
                    anchors.fill: parent
                    color: "black"
                    opacity: 1 - root.outro

                    Grid {
                        id: grid
                        anchors.horizontalCenter: parent.horizontalCenter
                        // Top, middle or bottom of the screen
                        y: root.style === 1 ? root.edgeMargin
                            : root.style === 0 ? parent.height - height - root.edgeMargin
                            : (parent.height - height) / 2
                        columns: root.vertical ? 1 : root.text.length
                        horizontalItemAlignment: Grid.AlignHCenter
                        scale: 1 + root.outro * 0.06

                        Repeater {
                            model: root.text.length

                            StyledText {
                                id: letter

                                required property int index

                                text: root.text[index]
                                font.family: Appearance.font.title
                                // A column of letters has to fit the screen height
                                font.pixelSize: root.vertical ? Math.min(64, Math.floor(window.height * 0.8 / root.text.length / 1.3)) : 64
                                font.weight: Font.DemiBold
                                color: "white"
                                elide: Text.ElideNone
                                // 0 (hidden) -> 1 (in place); the style decides what that looks like
                                property real rise: root.lettersIn ? 1 : 0
                                readonly property real away: 1 - rise
                                opacity: Math.min(1, rise)
                                transformOrigin: Item.Center
                                scale: root.style === 2 ? 0.2 + 0.8 * rise : 1
                                rotation: root.style === 4 ? away * -120 : 0
                                transform: Translate {
                                    x: root.style === 3 ? letter.away * (letter.index % 2 ? 90 : -90) : 0
                                    y: root.style === 0 ? letter.away * 28 : root.style === 1 ? letter.away * -36 : 0
                                }

                                Behavior on rise {
                                    SequentialAnimation {
                                        PauseAnimation { duration: letter.index * root.letterDelay }
                                        NumberAnimation {
                                            duration: root.style === 2 || root.style === 4 ? 550 : 400
                                            easing.type: root.style === 2 ? Easing.OutBack : Easing.OutCubic
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
