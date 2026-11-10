import QtQuick

// A keynote line that lands a word at a time: word i hits at `at + i * step` (seconds of `t`, the
// slide's own clock), slammed in big and tilted and snapping into place with a little overshoot.
// The words share the look of KeynoteText (white, or a gradient with `colors`).
Row {
    id: root

    property string text: ""
    property real t: 0
    property real at: 0
    property real step: 0.5
    property real size: 64
    property int weight: Font.Bold
    property color color: "white"
    property var colors: []
    property real time: 0
    property real kick: 0
    // How hard a word slams in: 0 just rises, 1 comes from twice the size
    property real slam: 0.7

    readonly property var words: text.split(" ").filter(w => w !== "")

    spacing: size * 0.32

    function clamp(x) {
        return Math.max(0, Math.min(1, x));
    }

    // 0 -> 1 with an overshoot
    function back(x) {
        const c = clamp(x), k = 2.2;
        return 1 + (k + 1) * Math.pow(c - 1, 3) + k * Math.pow(c - 1, 2);
    }

    Repeater {
        model: root.words.length

        KeynoteText {
            required property int index
            readonly property real q: (root.t - root.at - index * root.step) / 0.35

            text: root.words[index]
            size: root.size
            weight: root.weight
            color: root.color
            colors: root.colors
            time: root.time
            kick: root.kick
            shown: root.clamp(q * 2.5)
            scale: (1 + root.slam * (1 - root.back(q))) * (1 + 0.045 * root.kick)
            rotation: (index % 2 ? 6 : -6) * root.slam * (1 - root.clamp(q))
        }
    }
}
