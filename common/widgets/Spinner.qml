import QtQuick
import QtQuick.Shapes
import qs.common

// Material 3 style indeterminate circular progress indicator.
Item {
    id: root

    property color color: Colors.m3primary
    property real lineWidth: 3

    implicitWidth: 24
    implicitHeight: 24

    Shape {
        id: shape
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer

        ShapePath {
            strokeColor: root.color
            strokeWidth: root.lineWidth
            fillColor: "transparent"
            capStyle: ShapePath.RoundCap

            PathAngleArc {
                id: arc
                centerX: root.width / 2
                centerY: root.height / 2
                radiusX: root.width / 2 - root.lineWidth
                radiusY: root.height / 2 - root.lineWidth
                startAngle: 0
                sweepAngle: 90

                // Grow and shrink the arc while the whole shape rotates.
                SequentialAnimation on sweepAngle {
                    running: root.visible
                    loops: Animation.Infinite
                    NumberAnimation { from: 30; to: 270; duration: 700; easing.type: Easing.InOutCubic }
                    NumberAnimation { from: 270; to: 30; duration: 700; easing.type: Easing.InOutCubic }
                }
            }
        }

        RotationAnimator on rotation {
            running: root.visible
            from: 0
            to: 360
            duration: 1100
            loops: Animation.Infinite
        }
    }
}
