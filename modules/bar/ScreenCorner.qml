import QtQuick
import QtQuick.Shapes

// Concave rounded corner (filled outside a quarter circle), drawn where an
// edge-to-edge bar meets the screen side. Unflipped it sits at a top-left corner.
Shape {
    id: root

    property int size: 16
    property color color: "black"
    property bool flipX: false
    property bool flipY: false

    width: size
    height: size
    preferredRendererType: Shape.CurveRenderer
    transform: Scale {
        origin.x: root.width / 2
        origin.y: root.height / 2
        xScale: root.flipX ? -1 : 1
        yScale: root.flipY ? -1 : 1
    }

    ShapePath {
        fillColor: root.color
        strokeWidth: 0
        strokeColor: "transparent"
        startX: 0
        startY: 0
        PathLine { x: root.size; y: 0 }
        PathArc {
            x: 0
            y: root.size
            radiusX: root.size
            radiusY: root.size
            direction: PathArc.Counterclockwise
        }
        PathLine { x: 0; y: 0 }
    }
}
