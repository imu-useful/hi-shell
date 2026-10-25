import QtQuick
import Quickshell
import qs.common
import qs.common.widgets
import qs.common.shapes

// Analog clock on a Material cookie shape with ghosted numerals and
// day / month badges.
Item {
    id: root

    readonly property int size: 220
    readonly property real hours: clock.date.getHours() % 12 + clock.date.getMinutes() / 60
    readonly property real minutes: clock.date.getMinutes() + clock.date.getSeconds() / 60

    implicitWidth: size + 20
    implicitHeight: size + 20

    SystemClock {
        id: clock
        precision: SystemClock.Seconds
    }

    MaterialShape {
        id: face
        x: 10
        y: 10
        width: root.size
        height: root.size
        shape: "cookie12"
        color: Qt.alpha(Colors.m3secondaryContainer, 0.92)
    }

    // Ghosted 12 / 3 / 6 / 9
    Repeater {
        model: [{ t: "12", a: 0 }, { t: "3", a: 90 }, { t: "6", a: 180 }, { t: "9", a: 270 }]

        StyledText {
            required property var modelData
            readonly property real r: root.size * 0.33
            x: face.x + face.width / 2 + Math.sin(modelData.a * Math.PI / 180) * r - width / 2
            y: face.y + face.height / 2 - Math.cos(modelData.a * Math.PI / 180) * r - height / 2
            text: modelData.t
            font.family: Appearance.font.title
            font.pixelSize: 44
            font.weight: Font.Bold
            color: Qt.alpha(Colors.m3onSecondaryContainer, 0.16)
        }
    }

    // Rotates around (cx, cy), the clock center.
    component Hand: Rectangle {
        id: hand
        property real angle: 0
        property real length: 60
        property real cx: 0
        property real cy: 0
        x: cx - width / 2
        y: cy - length + width / 2
        height: length
        radius: width / 2
        antialiasing: true
        transform: Rotation {
            origin.x: hand.width / 2
            origin.y: hand.length - hand.width / 2
            angle: hand.angle
        }
    }

    Hand {
        width: 14
        length: root.size * 0.27
        angle: root.hours * 30
        cx: face.x + face.width / 2
        cy: face.y + face.height / 2
        color: Colors.m3primary
    }
    Hand {
        width: 8
        length: root.size * 0.38
        angle: root.minutes * 6
        cx: face.x + face.width / 2
        cy: face.y + face.height / 2
        color: Colors.m3onSecondaryContainer
    }

    // Seconds: a dot travelling just inside the edge.
    Rectangle {
        readonly property real a: clock.date.getSeconds() * 6 * Math.PI / 180
        readonly property real r: root.size * 0.40
        width: 10
        height: 10
        radius: 5
        x: face.x + face.width / 2 + Math.sin(a) * r - 5
        y: face.y + face.height / 2 - Math.cos(a) * r - 5
        color: Colors.m3tertiary
    }

    Rectangle {
        x: face.x + face.width / 2 - 8
        y: face.y + face.height / 2 - 8
        width: 16
        height: 16
        radius: 8
        color: Colors.m3primary
    }

    component Badge: Item {
        property string text
        property string shape
        property color fill
        property color ink
        width: 56
        height: 56
        MaterialShape {
            anchors.fill: parent
            shape: parent.shape
            color: parent.fill
        }
        StyledText {
            anchors.centerIn: parent
            text: parent.text
            font.family: Appearance.font.title
            font.pixelSize: 22
            font.weight: Font.DemiBold
            color: parent.ink
        }
    }

    Badge {
        x: 0
        y: 0
        shape: "cookie6"
        text: Qt.formatDate(clock.date, "dd")
        fill: Colors.m3tertiaryContainer
        ink: Colors.m3onTertiaryContainer
    }
    Badge {
        x: root.width - width
        y: root.height - height
        shape: "circle"
        text: Qt.formatDate(clock.date, "MM")
        fill: Colors.m3surfaceContainerHighest
        ink: Colors.m3onSurface
    }
}
