import QtQuick
import QtQuick.Effects
import QtQuick.Window
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
    // Extra picture around the shape, as a fraction of the size on each side. A turning
    // shape's tips reach past the square it fits in, and would be cut off without it.
    property real overscan: 0
    readonly property real stage: 1 + 2 * overscan

    implicitWidth: 64
    implicitHeight: 64

    Image {
        id: image
        anchors.centerIn: parent
        width: root.width * root.stage
        height: root.height * root.stage
        visible: false
        asynchronous: true
        fillMode: Image.PreserveAspectCrop
        // Decoded at the screen's pixel density, not more (a full-size picture each).
        sourceSize: Qt.size(Math.ceil(image.width * Screen.devicePixelRatio), Math.ceil(image.height * Screen.devicePixelRatio))
    }

    Item {
        id: maskLayer
        anchors.centerIn: parent
        width: image.width
        height: image.height
        visible: false
        layer.enabled: true

        MaterialShape {
            id: mask
            anchors.centerIn: parent
            width: root.width
            height: root.height
            rotation: root.maskRotation
            color: "black"
        }
    }

    MultiEffect {
        anchors.centerIn: parent
        width: image.width
        height: image.height
        source: image
        maskEnabled: true
        maskSource: maskLayer
        maskThresholdMin: 0.5
        maskSpreadAtMin: 1
    }
}
