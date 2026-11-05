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
            readonly property bool wanted: Island.enabled && Island.options.fullscreen && fullscreen && Island.alertActive

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
                    // Room for the message and the buttons; the mask keeps the rest click-through.
                    implicitHeight: Island.notif || Island.privacy ? 300 : pill.height + 32
                    mask: Region {
                        item: pill
                        regions: [Region { item: card }, Region { item: privacyCard.visible ? privacyCard : null }]
                    }
                    color: "transparent"

                    WlrLayershell.namespace: "hi-shell-island"
                    WlrLayershell.layer: WlrLayer.Overlay

                    // Hover the island: the message pops out in a second island. The buttons float under it
                    // all the time over a fullscreen window.
                    IslandHoverCard {
                        id: card
                        anchors.horizontalCenter: parent.horizontalCenter
                        y: pill.y + pill.height + 10
                        showMessage: loader.revealed && Island.notif !== null && Island.hovered
                        showButtons: loader.revealed && Island.notif !== null
                        floating: true
                        delay: 350

                        HoverHandler {
                            onHoveredChanged: Island.setHover("overlayCard", hovered)
                        }
                    }

                    // Hover the indicator: who is using the camera or the microphone.
                    Rectangle {
                        id: privacyCard

                        readonly property bool shown: loader.revealed && Island.privacy && Island.notif === null && Island.hovered

                        anchors.horizontalCenter: parent.horizontalCenter
                        y: pill.y + pill.height + 10
                        width: list.implicitWidth + 32
                        height: list.implicitHeight + 28
                        radius: Appearance.rounding.large
                        color: Appearance.translucent(Colors.m3surfaceContainerHighest, 0.05)
                        border.width: 1
                        border.color: Qt.alpha(Colors.m3outlineVariant, 0.6)
                        opacity: shown ? 1 : 0
                        visible: opacity > 0.01
                        Behavior on opacity { EffectAnim {} }

                        PrivacyList {
                            id: list
                            x: 16
                            y: 14
                        }

                        HoverHandler {
                            onHoveredChanged: Island.setHover("overlayPrivacy", hovered)
                        }
                    }

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
                        // Drops in and bounces like a ball, and goes back up quickly.
                        Behavior on slide {
                            NumberAnimation {
                                duration: loader.revealed ? 900 : Appearance.anim.normal
                                easing.type: loader.revealed ? Easing.OutBounce : Easing.InBack
                            }
                        }

                        HoverHandler {
                            onHoveredChanged: Island.setHover("overlay", hovered)
                        }

                        RowLayout {
                            id: content
                            anchors.centerIn: parent
                            spacing: 8

                            PrivacyPill {
                                visible: Island.privacy
                                Layout.alignment: Qt.AlignVCenter
                            }
                            IslandOsd {
                                visible: Island.showsOsd
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
                            acceptedButtons: Qt.LeftButton | Qt.RightButton
                            onPressed: if (Island.canSwitch) ShellState.startIslandHold()
                            onReleased: ShellState.endIslandHold()
                            onCanceled: ShellState.endIslandHold()
                            onClicked: mouse => {
                                if (!ShellState.islandHeld && Island.notif) {
                                    if (mouse.button === Qt.RightButton)
                                        Island.close(Island.notif);
                                    else
                                        Island.open();
                                }
                                ShellState.islandHeld = false;
                            }
                        }
                    }
                }
            }
        }
    }
}
