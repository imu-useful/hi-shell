import QtQuick
import qs.common
import qs.common.shapes

// Key "disco": a floor of tiles changing color on the beat, sweeping spotlights, a mirror ball.
Item {
    id: root

    required property bool revealed
    readonly property int bpm: 120
    readonly property int cols: 16
    readonly property int rows: 9
    property int beat: 0

    MusicLoop { file: "disco.ogg"; playing: root.revealed }

    Timer {
        interval: 60000 / root.bpm
        running: root.revealed
        repeat: true
        onTriggered: root.beat++
    }

    Grid {
        anchors.fill: parent
        columns: root.cols
        Repeater {
            model: root.cols * root.rows
            Rectangle {
                required property int index
                readonly property int col: index % root.cols
                readonly property int row: Math.floor(index / root.cols)
                width: root.width / root.cols
                height: root.height / root.rows
                color: Qt.hsla(((col + row) / (root.cols + root.rows) + root.beat * 0.13) % 1, 0.9, ((col + row + root.beat) % 2 ? 0.5 : 0.3), 1)
                opacity: 0.55
                Behavior on color { ColorAnimation { duration: 120 } }
            }
        }
    }

    // Spotlight beams from the top, swinging in turn
    Repeater {
        model: 5
        Rectangle {
            id: beam
            required property int index
            width: root.width * 0.12
            height: root.height * 1.4
            x: root.width * (0.1 + index * 0.2) - width / 2
            y: -height * 0.05
            transformOrigin: Item.Top
            color: Qt.hsla((index / 5 + root.beat * 0.08) % 1, 1, 0.65, 0.22)
            radius: width / 2
            rotation: 0
            Behavior on color { ColorAnimation { duration: 150 } }
            SequentialAnimation on rotation {
                running: root.revealed
                loops: Animation.Infinite
                NumberAnimation { to: 28 * (beam.index % 2 ? 1 : -1); duration: 1400 + beam.index * 160; easing.type: Easing.InOutSine }
                NumberAnimation { to: -28 * (beam.index % 2 ? 1 : -1); duration: 1400 + beam.index * 160; easing.type: Easing.InOutSine }
            }
        }
    }

    // Mirror ball: a silver disc, with a lattice that slides to look like it's turning
    Item {
        id: ball
        readonly property real size: Math.min(root.width, root.height) * 0.3
        width: size
        height: size
        anchors.horizontalCenter: parent.horizontalCenter
        y: root.height * 0.05
        scale: 1 + (root.beat % 2) * 0.04
        Behavior on scale { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }

        Rectangle {
            anchors.fill: parent
            radius: width / 2
            gradient: Gradient {
                GradientStop { position: 0; color: "#ffffff" }
                GradientStop { position: 0.6; color: "#9aa0a6" }
                GradientStop { position: 1; color: "#3c4043" }
            }
        }
        Item {
            anchors.fill: parent
            clip: true
            layer.enabled: true
            Repeater {
                model: 14
                Rectangle {
                    required property int index
                    width: 2; height: parent.height
                    x: ((index * ball.size / 7 + root.beat * 9) % ball.size)
                    color: "#55000000"
                }
            }
            Repeater {
                model: 14
                Rectangle {
                    required property int index
                    height: 2; width: parent.width
                    y: index * ball.size / 14
                    color: "#55000000"
                }
            }
        }
        Repeater {
            model: 8
            MaterialShape {
                required property int index
                width: 36; height: 36
                shape: "star"
                animated: false
                color: "white"
                x: ball.size / 2 + Math.cos(index * 0.785 + root.beat) * ball.size * 0.7 - 18
                y: ball.size / 2 + Math.sin(index * 0.785 + root.beat) * ball.size * 0.7 - 18
                scale: (root.beat + index) % 3 === 0 ? 1.3 : 0.4
                Behavior on scale { NumberAnimation { duration: 200 } }
                Behavior on x { NumberAnimation { duration: 400 } }
                Behavior on y { NumberAnimation { duration: 400 } }
            }
        }
    }
}
