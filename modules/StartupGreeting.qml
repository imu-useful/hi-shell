import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.common
import qs.common.widgets

// "Welcome back!" at startup: the letters rise in one after another, the line stays a moment
// and fades away; then the window is gone. Starts with the rest of the startup animation.
Scope {
    id: root

    readonly property string text: "Welcome back!"
    readonly property int letterDelay: 55
    // 0..1 for the whole line, drives the exit fade
    property real outro: 0
    property bool done: false

    Connections {
        target: ShellState
        function onStartedChanged() {
            if (ShellState.started && !root.done)
                holdTimer.start();
        }
    }

    // Letters come in over text.length * letterDelay + a letter's own animation, then a hold.
    Timer {
        id: holdTimer
        interval: root.text.length * root.letterDelay + 400 + 1400
        onTriggered: fadeOut.start()
    }

    NumberAnimation {
        id: fadeOut
        target: root
        property: "outro"
        to: 1
        duration: 600
        easing.type: Easing.InOutCubic
        onFinished: root.done = true
    }

    LazyLoader {
        active: Appearance.anim.speed > 0 && !root.done

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

                Row {
                    id: line
                    anchors.centerIn: parent
                    opacity: 1 - root.outro
                    scale: 1 + root.outro * 0.06

                    Repeater {
                        model: root.text.length

                        StyledText {
                            id: letter

                            required property int index
                            readonly property bool shown: ShellState.started

                            text: root.text[index]
                            font.family: Appearance.font.title
                            font.pixelSize: 64
                            font.weight: Font.DemiBold
                            color: Colors.m3onSurface
                            elide: Text.ElideNone
                            property real rise: shown ? 1 : 0
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
