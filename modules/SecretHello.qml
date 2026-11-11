import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import qs.common
import qs.common.widgets
import qs.modules.secret

// Easter egg (Settings › About, the key "hi"): a full-screen surprise picked by the key: "hi" the animated
// logo, "matrix", "confetti", "sudo", "arch", "42", "disco", "nyan", "man", "egg", "undertale", "story", "mania", "osu", "math" (also "maths", "математика"), "material" (also "material you", "m3", "expressive"), "liquid glass" (also "liquid", "glass", "lg"), "nothing" (also "nothing os", "nothingos", "nothing ui", "nothingui", "ndot"), "coloros" (also "color os", "oppo", "aquamorphic"), "oneui" (also "one ui", "samsung"), "hyperos" (also "hyper os", "xiaomi"), "aero" (also "frutiger", "frutiger aero"), "rice" (also "ricing", "eye candy", "eyecandy", "trip"), "keynote" (also "presentation", "презентация", "event"). A click or Esc closes it.
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
                        undertale: story,
                        story: story,
                        mania: mania,
                        osu: mania,
                        math: mathrush,
                        maths: mathrush,
                        "математика": mathrush,
                        material: material,
                        "liquid glass": glass,
                        nothing: nothing,
                        aero: aero,
                        rice: eyecandy,
                        keynote: keynote,
                        presentation: keynote,
                        "презентация": keynote,
                        event: keynote,
                        ricing: eyecandy,
                        "eye candy": eyecandy,
                        eyecandy: eyecandy,
                        trip: eyecandy,
                        frutiger: aero,
                        "frutiger aero": aero,
                        hyperos: hyperos,
                        "hyper os": hyperos,
                        xiaomi: hyperos,
                        oneui: oneui,
                        "one ui": oneui,
                        samsung: oneui,
                        coloros: coloros,
                        "color os": coloros,
                        oppo: coloros,
                        aquamorphic: coloros,
                        "nothing os": nothing,
                        nothingos: nothing,
                        "nothing ui": nothing,
                        nothingui: nothing,
                        ndot: nothing,
                        liquid: glass,
                        glass: glass,
                        lg: glass,
                        "material you": material,
                        m3: material,
                        expressive: material,
                        egg: man,
                        "42": answer
                    })[root.egg] ?? null
                }

                Component { id: hello; HelloLogo { anchors.centerIn: parent; revealed: loader.revealed; screenWidth: window.width; screenHeight: window.height } }
                Component { id: matrix; MatrixRain { revealed: loader.revealed } }
                Component { id: confetti; Confetti { revealed: loader.revealed } }
                Component { id: disco; Disco { revealed: loader.revealed } }
                Component { id: nyan; Nyan { revealed: loader.revealed } }
                Component { id: keynote; Keynote { revealed: loader.revealed } }
                Component { id: eyecandy; EyeCandy { revealed: loader.revealed } }
                Component { id: aero; FrutigerAero { revealed: loader.revealed } }
                Component { id: hyperos; HyperOS { revealed: loader.revealed } }
                Component { id: oneui; OneUI { revealed: loader.revealed } }
                Component { id: coloros; ColorOS { revealed: loader.revealed } }
                Component { id: nothing; NothingUI { revealed: loader.revealed } }
                Component { id: glass; LiquidGlass { revealed: loader.revealed } }
                Component { id: material; MaterialYou { revealed: loader.revealed } }
                Component { id: mania; Mania { revealed: loader.revealed } }
                Component { id: mathrush; MathRush { revealed: loader.revealed } }
                Component { id: man; Man { revealed: loader.revealed } }
                Component { id: story; Story { revealed: loader.revealed; onFinished: root.close() } }
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
