import QtQuick
import QtQuick.Effects

// An image clipped to a rounded square (a cover, the wallpaper frame).
Item {
    id: root

    property alias source: image.source
    property real radius: 32

    Image {
        id: image
        anchors.fill: parent
        visible: false
        asynchronous: true
        fillMode: Image.PreserveAspectCrop
        sourceSize: Qt.size(root.width, root.height)
    }
    Item {
        id: mask
        anchors.fill: parent
        visible: false
        layer.enabled: true
        Rectangle {
            anchors.fill: parent
            radius: root.radius
            color: "black"
        }
    }
    MultiEffect {
        anchors.fill: parent
        source: image
        maskEnabled: true
        maskSource: mask
        maskThresholdMin: 0.5
        maskSpreadAtMin: 1
    }
}
