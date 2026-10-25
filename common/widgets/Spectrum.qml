import QtQuick
import Quickshell
import Quickshell.Io
import qs.common

// Audio spectrum from cava, drawn by one shader (shaders/spectrum.frag): the CPU only
// hands over the levels, so it stays cheap at 60 fps. Runs cava while `active`.
ShaderEffect {
    id: root

    property bool active: false
    // A real, not an int: shader uniforms take the raw value, and the shader reads a float.
    property real bars: 16 // up to 64
    property color color: Colors.m3primary
    // bottom: bars grow up from the bottom edge | center: side by side, centered | stacked: one above another
    property string mode: "bottom"
    property real gap: 2
    property real minLength: 3
    // cava smooths between frames; 30 keeps the motion fluid without redrawing
    // the window at the full display rate for as long as music plays.
    property int framerate: 30

    property list<real> levels: []

    // cava reads its config from a file; raw ASCII output, one frame per line ("12;40;7;...").
    // The file is removed once cava has read it.
    Process {
        running: root.active && Appearance.anim.speed > 0
        command: ["sh", "-c", 'cfg=$(mktemp); printf "%b" "$1" > "$cfg"; (sleep 2; rm -f "$cfg") & exec cava -p "$cfg"', "sh",
            `[general]\nbars = ${Math.min(64, root.bars)}\nframerate = ${root.framerate}\n[input]\nmethod = pipewire\n[output]\nmethod = raw\nraw_target = /dev/stdout\ndata_format = ascii\nascii_max_range = 100\nbar_delimiter = 59\n[smoothing]\nmonstercat = 1\nnoise_reduction = 70\n`]
        stdout: SplitParser {
            onRead: line => root.levels = line.split(";").filter(v => v !== "").map(v => Number(v) / 100)
        }
        onRunningChanged: if (!running) root.levels = []
    }

    // Shader inputs
    readonly property vector2d size: Qt.vector2d(width, height)
    readonly property real orient: mode === "stacked" ? 2 : mode === "center" ? 1 : 0
    function quad(i: int): vector4d {
        const l = levels;
        return Qt.vector4d(l[i * 4] ?? 0, l[i * 4 + 1] ?? 0, l[i * 4 + 2] ?? 0, l[i * 4 + 3] ?? 0);
    }
    readonly property vector4d l0: quad(0)
    readonly property vector4d l1: quad(1)
    readonly property vector4d l2: quad(2)
    readonly property vector4d l3: quad(3)
    readonly property vector4d l4: quad(4)
    readonly property vector4d l5: quad(5)
    readonly property vector4d l6: quad(6)
    readonly property vector4d l7: quad(7)
    readonly property vector4d l8: quad(8)
    readonly property vector4d l9: quad(9)
    readonly property vector4d l10: quad(10)
    readonly property vector4d l11: quad(11)
    readonly property vector4d l12: quad(12)
    readonly property vector4d l13: quad(13)
    readonly property vector4d l14: quad(14)
    readonly property vector4d l15: quad(15)

    fragmentShader: Qt.resolvedUrl("shaders/spectrum.frag.qsb")
}
