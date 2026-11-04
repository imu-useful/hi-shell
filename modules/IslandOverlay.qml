import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.common
import qs.common.widgets
import qs.modules.bar
import qs.services

// The Dynamic Island over a fullscreen window: the bar is hidden there, so the island detaches and
// floats at the top centre of the screen. It slides down while it has something to show
// (ShellState.islandAlert, set by the alerts of the later stages; for now also a short peek when
// fullscreen starts) and slides back up when that is over. One per screen.
Scope {
    id: root

    Variants {
        model: Quickshell.screens

        Scope {
            id: perScreen

            required property var modelData
            readonly property bool fullscreen: Fullscreen.on(modelData.name)
            readonly property bool wanted: fullscreen && (ShellState.islandAlert || peek.running)

            // Fullscreen just started: show the island for a moment.
            onFullscreenChanged: if (fullscreen) peek.restart()

            Timer {
                id: peek
                interval: 3000
            }

            PanelLoader {
                id: loader
                shown: perScreen.wanted
                closeDelay: Appearance.anim.spatial + 100

                PanelWindow {
                    id: window

                    screen: perScreen.modelData
                    anchors.top: true
                    // Ignore the bar's reserved strip: the island sits at the very top of the screen.
                    exclusionMode: ExclusionMode.Ignore
                    implicitWidth: pill.width + 32
                    implicitHeight: pill.height + 32
                    mask: Region { item: pill }
                    color: "transparent"

                    WlrLayershell.namespace: "hi-shell-island"
                    WlrLayershell.layer: WlrLayer.Overlay

                    Rectangle {
                        id: pill

                        property real slide: loader.revealed ? 1 : 0

                        anchors.horizontalCenter: parent.horizontalCenter
                        // Slides down from above the screen edge and back up.
                        y: 12 - (1 - slide) * (height + 24)
                        width: Math.max(96, time.implicitWidth + 40)
                        height: 36
                        radius: height / 2
                        color: Appearance.translucent(Colors.m3surfaceContainerHighest, 0.05)
                        border.width: 1
                        border.color: Qt.alpha(Colors.m3outlineVariant, 0.6)
                        Behavior on slide { SpatialAnim {} }

                        SystemClock {
                            id: clock
                            precision: SystemClock.Minutes
                        }

                        StyledText {
                            id: time
                            anchors.centerIn: parent
                            text: Qt.formatDateTime(clock.date, Config.options.bar.clock.timeFormat)
                            font.pixelSize: Appearance.font.size.normal
                            font.weight: Font.DemiBold
                            font.features: { "tnum": 1 }
                        }

                        HoldRing {
                            anchors.fill: parent
                            progress: ShellState.islandHold
                        }

                        // Same hold as on the clock in the bar: it switches the island's state.
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onPressed: ShellState.startIslandHold()
                            onReleased: ShellState.endIslandHold()
                            onCanceled: ShellState.endIslandHold()
                        }
                    }
                }
            }
        }
    }
}
