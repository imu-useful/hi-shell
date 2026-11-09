import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import qs.common
import qs.common.widgets

// Easter egg (Settings › About, the key "hi"): a full-screen "Hi to you too" over the animated
// logo. A click or Esc closes it.
Scope {
    id: root

    readonly property bool open: ShellState.secretHello

    function close(): void {
        ShellState.secretHello = false;
    }

    PanelLoader {
        id: loader
        shown: root.open

        PanelWindow {
            id: window

            screen: Quickshell.screens.find(s => s.name === Hyprland.focusedMonitor?.name) ?? Quickshell.screens[0]
            anchors.top: true
            anchors.bottom: true
            anchors.left: true
            anchors.right: true
            exclusionMode: ExclusionMode.Ignore
            color: "transparent"

            WlrLayershell.namespace: "hi-shell-secret"
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.keyboardFocus: root.open ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

            Shortcut {
                sequence: "Escape"
                onActivated: root.close()
            }

            Rectangle {
                anchors.fill: parent
                color: "black"
                opacity: loader.revealed ? 1 : 0
                Behavior on opacity { NumberAnimation { duration: 500; easing.type: Easing.OutCubic } }

                MouseArea {
                    anchors.fill: parent
                    onClicked: root.close()
                }

                Column {
                    anchors.centerIn: parent
                    spacing: 32

                    StyledText {
                        id: greeting
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: Translation.tr("Hi to you too")
                        font.family: Appearance.font.title
                        font.pixelSize: Math.min(96, window.width / 12)
                        font.weight: Font.DemiBold
                        color: "white"
                        elide: Text.ElideNone
                        property real rise: loader.revealed ? 1 : 0
                        opacity: rise
                        transform: Translate { y: (1 - greeting.rise) * 24 }
                        Behavior on rise { NumberAnimation { duration: 700; easing.type: Easing.OutCubic } }
                    }

                    AnimatedLogo {
                        anchors.horizontalCenter: parent.horizontalCenter
                        height: Math.min(320, window.height * 0.4)
                        playing: loader.revealed
                    }
                }
            }
        }
    }
}
