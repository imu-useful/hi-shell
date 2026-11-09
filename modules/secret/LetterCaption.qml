import QtQuick
import qs.common
import qs.common.widgets

// A caption that plays letter by letter over one scene of `sceneLength` seconds. Each letter
// springs up (rising, growing, straightening) a beat after the one before; colors drift along the
// word with `hue`; in the pause the line ripples gently; at the end the letters leave in the
// same order. A bar of light grows under the words. `time` is the running clock, `sceneTime`
// the seconds since the scene (and so this caption) began.
Item {
    id: root

    property string text: ""
    property real time: 0
    property real sceneTime: 0
    property real sceneLength: 7
    property real hue: 0.6
    property real fontSize: 72
    // The letters' color: pastel light by default (for dark scenes); lower the lightness for a light one
    property real saturation: 0.85
    property real lightness: 0.78

    readonly property real appear: spring((sceneTime - 0.1) / 0.9)
    readonly property real leave: clamp((sceneLength - sceneTime) / 0.4)

    width: letters.width
    height: letters.height + 30

    function clamp(x) {
        return Math.max(0, Math.min(1, x));
    }

    // 0 -> 1 with an overshoot
    function spring(p) {
        const x = clamp(p);
        return 1 - Math.exp(-7 * x) * Math.cos(13 * x);
    }

    function toneColor(offset, sat, light, alpha) {
        return Qt.hsla((((root.hue + offset) % 1) + 1) % 1, sat, light, alpha);
    }

    Row {
        id: letters
        anchors.horizontalCenter: parent.horizontalCenter
        spacing: 0

        Repeater {
            model: root.text.length

            StyledText {
                id: letter

                required property int index
                // How far this letter is into its entrance / exit (0..1, springy on the way in)
                readonly property real inP: root.spring((root.sceneTime - 0.05 - index * 0.05) / 0.65)
                readonly property real outP: root.clamp((root.sceneLength - root.sceneTime - index * 0.025) / 0.35)
                readonly property real show: Math.min(1, inP * 1.6) * outP

                text: root.text[index]
                font.family: Appearance.font.title
                font.pixelSize: root.fontSize
                font.weight: Font.Bold
                elide: Text.ElideNone
                color: root.toneColor(index * 0.03 + root.time * 0.05, root.saturation, root.lightness + 0.06 * Math.sin(root.time * 2 - index * 0.6), 1)
                opacity: show
                transformOrigin: Item.Center
                scale: (0.35 + 0.65 * inP) * (0.8 + 0.2 * outP)
                rotation: (1 - inP) * (index % 2 ? -14 : 14) + (1 - outP) * (index % 2 ? 10 : -10)
                transform: Translate {
                    y: (1 - letter.inP) * 70 + (1 - letter.outP) * -30 + Math.sin(root.time * 2.4 + letter.index * 0.55) * 4 * letter.show
                }
            }
        }
    }

    Rectangle {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: letters.bottom
        anchors.topMargin: 10
        height: 6
        radius: 3
        width: letters.width * 0.7 * Math.max(0, root.appear) * root.leave
        opacity: root.leave
        gradient: Gradient {
            orientation: Gradient.Horizontal
            GradientStop { position: 0; color: root.toneColor(0, 0.9, 0.62, 0) }
            GradientStop { position: 0.2; color: root.toneColor(0, 0.9, 0.62, 1) }
            GradientStop { position: 0.5; color: root.toneColor(0.28, 0.75, 0.68, 1) }
            GradientStop { position: 0.8; color: root.toneColor(0.11, 0.6, 0.72, 1) }
            GradientStop { position: 1; color: root.toneColor(0.11, 0.6, 0.72, 0) }
        }
    }
}
