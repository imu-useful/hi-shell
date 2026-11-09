import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import qs.common
import qs.common.widgets
import qs.modules.secret

// Easter egg (Settings › About, the key "hi"): a full-screen surprise picked by the key: "hi" the animated
// logo, "matrix", "confetti", "sudo", "arch", "42", "disco", "nyan", "man", "egg". A click or Esc closes it.
Scope {
    id: root

    readonly property string egg: ShellState.secretEgg
    readonly property bool open: egg !== ""

    function close(): void {
        ShellState.secretEgg = "";
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

                Loader {
                    anchors.fill: parent
                    sourceComponent: ({
                        hi: hello,
                        matrix: matrix,
                        confetti: confetti,
                        sudo: sudo,
                        arch: arch,
                        disco: disco,
                        nyan: nyan,
                        man: man,
                        egg: man,
                        "42": answer
                    })[root.egg] ?? null
                }

                Component { id: hello; HelloLogo { anchors.centerIn: parent; revealed: loader.revealed; screenWidth: window.width; screenHeight: window.height } }
                Component { id: matrix; MatrixRain { revealed: loader.revealed } }
                Component { id: confetti; Confetti { revealed: loader.revealed } }
                Component { id: disco; Disco { revealed: loader.revealed } }
                Component { id: nyan; Nyan { revealed: loader.revealed } }
                Component { id: man; Man { revealed: loader.revealed } }
                Component {
                    id: sudo
                    Terminal {
                        revealed: loader.revealed
                        prompt: "$ sudo rm -rf /\n"
                        message: Translation.tr("hi is not in the sudoers file. This incident will be reported.")
                    }
                }
                Component {
                    id: arch
                    Terminal {
                        revealed: loader.revealed
                        prompt: "$ neofetch\n"
                        message: Translation.tr("I use Arch, btw.")
                    }
                }
                Component {
                    id: answer
                    Terminal {
                        revealed: loader.revealed
                        prompt: "$ deep-thought --question 'life, the universe and everything'\n"
                        message: Translation.tr("42. Now you only need the question.")
                    }
                }
            }
        }
    }
}
