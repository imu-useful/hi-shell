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

                    Row {
                        anchors.centerIn: parent
                        scale: 1 + root.outro * 0.06

                        Repeater {
                            model: root.text.length

                            StyledText {
                                id: letter

                                required property int index

                                text: root.text[index]
                                font.family: Appearance.font.title
                                font.pixelSize: 64
                                font.weight: Font.DemiBold
                                color: "white"
                                elide: Text.ElideNone
                                property real rise: root.lettersIn ? 1 : 0
                                opacity: rise
                                transform: Translate { y: (1 - letter.rise) * 28 }

                                Behavior on rise {
                                    SequentialAnimation {
                                        PauseAnimation { duration: letter.index * root.letterDelay }
                                        NumberAnimation { duration: 400; easing.type: Easing.OutCubic }
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
