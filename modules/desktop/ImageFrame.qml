import QtQuick
import qs.common
import qs.common.shapes

// A picture (Config desktop.image, or the wallpaper) in a sunny shape.
Item {
    implicitWidth: 320
    implicitHeight: 320

    MaterialShape {
        anchors.fill: parent
        shape: "sunny"
        color: Colors.m3primary
    }
    ShapeImage {
        anchors.fill: parent
        anchors.margins: 8
        shape: "sunny"
        source: Config.options.desktop.image ? `file://${Config.options.desktop.image}` : Colors.wallpaper ? `file://${Colors.wallpaper}` : ""
    }
}
