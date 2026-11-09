import QtQuick
import qs.common
import qs.common.shapes
import qs.common.widgets

// Key "confetti": Material shapes rain down in the theme's colors.
Item {
    id: root

    required property bool revealed
    readonly property var shapes: ["star", "cookie6", "clover4", "flower", "sunny", "pill", "diamond", "burst"]
    readonly property var palette: [Colors.m3primary, Colors.m3secondary, Colors.m3tertiary, Colors.m3primaryContainer, Colors.m3tertiaryContainer, Colors.m3errorContainer]

    Repeater {
        model: root.revealed ? 70 : 0

        MaterialShape {
            id: piece

            required property int index
            readonly property real size: 22 + Math.random() * 40
            readonly property int fall: 3500 + Math.random() * 3500

            width: size
            height: size
            animated: false
            shape: root.shapes[index % root.shapes.length]
            color: root.palette[Math.floor(Math.random() * root.palette.length)]
            x: Math.random() * (root.width - size)
            y: -size

            SequentialAnimation {
                running: true
                PauseAnimation { duration: Math.random() * 2500 }
                ParallelAnimation {
                    loops: Animation.Infinite
                    NumberAnimation { target: piece; property: "y"; from: -piece.size; to: root.height; duration: piece.fall }
                    NumberAnimation { target: piece; property: "rotation"; from: 0; to: (piece.index % 2 ? 360 : -360); duration: piece.fall }
                }
            }
        }
    }

    StyledText {
        anchors.centerIn: parent
        text: "🎉"
        font.pixelSize: 140
        opacity: root.revealed ? 1 : 0
        scale: root.revealed ? 1 : 0.2
        Behavior on opacity { NumberAnimation { duration: 400 } }
        Behavior on scale { NumberAnimation { duration: 700; easing.type: Easing.OutBack } }
    }
}
