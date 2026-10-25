import QtQuick
import QtQuick.Effects
import qs.common

// Image clipped to a Material shape (avatars, album art, wallpaper frame).
Item {
    id: root

    property alias source: image.source
    property alias fillMode: image.fillMode
    property alias status: image.status
    property alias shape: mask.shape
    property alias shapeRotation: mask.shapeRotation
    // Turns only the outline (the picture stays upright); cheap to animate,
    // unlike shapeRotation, which recomputes the shape.
    property real maskRotation: 0

    implicitWidth: 64
    implicitHeight: 64

    Image {
        id: image
        anchors.fill: parent
        visible: false
        asynchronous: true
        fillMode: Image.PreserveAspectCrop
        sourceSize: Qt.size(root.width * 2, root.height * 2)
    }

    Item {
        id: maskLayer
        anchors.fill: parent
        visible: false
        layer.enabled: true

        MaterialShape {
            id: mask
            anchors.fill: parent
            rotation: root.maskRotation
            color: "black"
        }
    }

    MultiEffect {
        anchors.fill: parent
        source: image
        maskEnabled: true
        maskSource: maskLayer
        maskThresholdMin: 0.5
        maskSpreadAtMin: 1
    }
}
