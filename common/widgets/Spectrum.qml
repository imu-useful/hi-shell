import QtQuick
import Quickshell
import qs.common
import qs.services

// Audio spectrum drawn by one shader (shaders/spectrum.frag): the CPU only hands over
// the levels, from the shared cava in services/Beat while `active`.
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
    // Levels from the shared cava (services/Beat), averaged down to `bars`.
    readonly property list<real> levels: {
        const src = Beat.levels;
        if (!src.length)
            return [];
        const n = Math.min(64, Math.round(bars)), out = [];
        for (let i = 0; i < n; i++) {
            const a = Math.floor(i * src.length / n), b = Math.max(a + 1, Math.floor((i + 1) * src.length / n));
            let sum = 0;
            for (let j = a; j < b; j++)
                sum += src[j];
            out.push(sum / (b - a));
        }
        return out;
    }

    // Count in with Beat while active.
    property bool counted: false
    function syncUse() {
        const want = active && visible;
        if (want !== counted) {
            Beat.users += want ? 1 : -1;
            counted = want;
        }
    }
    onActiveChanged: syncUse()
    onVisibleChanged: syncUse()
    Component.onCompleted: syncUse()
    Component.onDestruction: if (counted) Beat.users--

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
