import QtQuick
import QtQuick.Shapes
import qs.common

// Ring progress indicator (0..1) with optional content in the middle.
Item {
    id: root

    property real value: 0
    property real lineWidth: 2.5
    property color color: Colors.m3primary
    property color trackColor: Colors.m3secondaryContainer
    default property alias content: center.data

    implicitWidth: 24
    implicitHeight: 24

    property real shown: Math.max(0, Math.min(1, value))
    Behavior on shown { EffectAnim { duration: Appearance.anim.slow } }

    Shape {
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer

        ShapePath {
            fillColor: "transparent"
            strokeColor: root.trackColor
            strokeWidth: root.lineWidth
            capStyle: ShapePath.RoundCap
            PathAngleArc {
                centerX: root.width / 2
                centerY: root.height / 2
                radiusX: (root.width - root.lineWidth) / 2
                radiusY: radiusX
                startAngle: -90
                sweepAngle: 360
            }
        }

        ShapePath {
            fillColor: "transparent"
            strokeColor: root.color
            strokeWidth: root.lineWidth
            capStyle: ShapePath.RoundCap
            PathAngleArc {
                centerX: root.width / 2
                centerY: root.height / 2
                radiusX: (root.width - root.lineWidth) / 2
                radiusY: radiusX
                startAngle: -90
                sweepAngle: 360 * root.shown
            }
        }
    }

    Item {
        id: center
        anchors.fill: parent
    }
}
