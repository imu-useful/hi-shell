import QtQuick
import QtQuick.Shapes
import qs.common
import "Shapes.js" as Shapes

// Filled Material 3 Expressive shape (cookie, clover, sunny, blob, ...) that
// stretches to its size. Changing `shape` or `shapeRotation` morphs smoothly.
// Names: see `Shapes.names` in Shapes.js.
Item {
    id: root

    property string shape: "circle"
    property real shapeRotation: 0
    property color color: Colors.m3primary
    property color borderColor: "transparent"
    property real borderWidth: 0
    property bool animated: true
    // How long a change of shape takes, and its curve (a spring by default).
    property int morphDuration: Appearance.anim.spatial
    property list<real> morphCurve: Appearance.anim.spatialFast

    implicitWidth: 48
    implicitHeight: 48

    property var from: Shapes.points(shape, shapeRotation)
    property var to: from
    property real progress: 1
    // The spatial curve overshoots past 1, which extrapolates the morph a little (springy).
    readonly property var current: morph.running ? Shapes.mix(from, to, progress) : to

    function retarget() {
        const next = Shapes.points(shape, shapeRotation);
        if (!animated || Appearance.anim.speed === 0) {
            morph.stop();
            from = to = next;
            return;
        }
        from = current;
        to = next;
        morph.restart();
    }

    onShapeChanged: retarget()
    onShapeRotationChanged: retarget()

    NumberAnimation {
        id: morph
        target: root
        property: "progress"
        from: 0
        to: 1
        duration: root.morphDuration
        easing.type: Easing.BezierSpline
        easing.bezierCurve: root.morphCurve
    }

    // Wrapped in an Item: Shape sets its own implicit size from the path, which
    // would feed back into the path size.
    Shape {
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer

        ShapePath {
            fillColor: root.color
            strokeColor: root.borderColor
            strokeWidth: root.borderWidth
            PathPolyline {
                path: Shapes.toPath(root.current, root.width, root.height)
            }
        }
    }
}
