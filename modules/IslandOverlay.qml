import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import qs.common
import qs.common.widgets
import qs.modules.bar
import qs.services

// The Dynamic Island over a fullscreen window: the bar is hidden there, so the island detaches and
// floats at the top centre of the screen. It slides down while there is an alert (a notification,
// the camera or microphone in use: Island.alertActive) and slides back up when that is over.
// One per screen.
Scope {
    id: root

    Variants {
        model: Quickshell.screens

        Scope {
            id: perScreen

            required property var modelData
            readonly property bool fullscreen: Fullscreen.on(modelData.name)
            readonly property bool wanted: fullscreen && Island.alertActive

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
                        width: Math.max(48, content.implicitWidth + (Island.notif ? 0 : 24))
                        Behavior on width { SpatialAnim {} }
                        height: 38
                        radius: height / 2
                        color: Appearance.translucent(Colors.m3surfaceContainerHighest, 0.05)
                        border.width: 1
                        border.color: Qt.alpha(Colors.m3outlineVariant, 0.6)
                        Behavior on slide { SpatialAnim {} }

                        RowLayout {
                            id: content
                            anchors.centerIn: parent
                            spacing: 8

                            PrivacyPill {
                                visible: Privacy.active
                                Layout.alignment: Qt.AlignVCenter
                            }
                            IslandNotification {
                                visible: Island.notif !== null
                                Layout.preferredWidth: implicitWidth
                                Layout.preferredHeight: implicitHeight
                            }
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
                            onClicked: {
                                if (!ShellState.islandHeld && Island.notif)
                                    Notifications.hidePopup(Island.notif.uid);
                                ShellState.islandHeld = false;
                            }
                        }
                    }
                }
            }
        }
    }
}
