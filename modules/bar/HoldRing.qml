import QtQuick
import QtQuick.Shapes
import qs.common

// A ring drawn along the border of a pill, clockwise from the top centre, as far as `progress` (0..1).
Shape {
    id: root

    property real progress: 0
    property color color: Colors.m3primary

    visible: progress > 0
    preferredRendererType: Shape.CurveRenderer

    readonly property real stroke: 2.5
    readonly property real r: Math.max(0, height / 2 - stroke / 2)
    readonly property real x0: stroke / 2
    readonly property real x1: width - stroke / 2
    readonly property real y0: stroke / 2
    readonly property real y1: height - stroke / 2
    readonly property real straight: Math.max(0, x1 - x0 - 2 * r)
    readonly property real perimeter: 2 * straight + 2 * Math.PI * r

    ShapePath {
        fillColor: "transparent"
        strokeColor: root.color
        strokeWidth: root.stroke
        capStyle: ShapePath.RoundCap
        // Dashes are in stroke widths: one dash as long as the progress, then a gap past the end.
        strokeStyle: ShapePath.DashLine
        dashPattern: [Math.max(0.001, root.progress * root.perimeter / root.stroke), root.perimeter / root.stroke + 1]

        startX: (root.x0 + root.x1) / 2
        startY: root.y0
        PathLine { x: root.x1 - root.r; y: root.y0 }
        PathArc { x: root.x1 - root.r; y: root.y1; radiusX: root.r; radiusY: root.r }
        PathLine { x: root.x0 + root.r; y: root.y1 }
        PathArc { x: root.x0 + root.r; y: root.y0; radiusX: root.r; radiusY: root.r }
        PathLine { x: (root.x0 + root.x1) / 2; y: root.y0 }
    }
}
