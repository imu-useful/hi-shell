import QtQuick
import QtQuick.Layouts
import qs.common
import qs.common.shapes
import "../shapes/Shapes.js" as ShapeData

// The wallpaper frame to choose: a tile per shape (drawn as the shape), and the chosen
// one's name under them. The list is `frames` in common/shapes/Shapes.js; "" = no frame.
ColumnLayout {
    id: root

    property string current: ""
    signal picked(string id)

    readonly property string currentName: (ShapeData.frames.find(f => f[0] === current) ?? ["", "None"])[1]

    spacing: 8

    Flow {
        Layout.fillWidth: true
        spacing: 6

        Repeater {
            model: ShapeData.frames

            Rectangle {
                id: tile
                required property var modelData
                readonly property bool selected: root.current === modelData[0]

                implicitWidth: 46
                implicitHeight: 46
                radius: selected ? 16 : 23
                color: selected ? Colors.m3secondaryContainer : Colors.m3surfaceContainerHigh
                border.width: selected ? 2 : 0
                border.color: Colors.m3primary
                Behavior on radius { SpringAnim {} }
                Behavior on color { ColorAnim {} }

                MaterialShape {
                    visible: tile.modelData[0] !== ""
                    anchors.centerIn: parent
                    implicitWidth: 28
                    implicitHeight: 28
                    shape: tile.modelData[0] || "circle"
                    animated: false
                    color: tile.selected ? Colors.m3primary : Colors.m3onSurfaceVariant
                }
                MaterialIcon {
                    visible: tile.modelData[0] === ""
                    anchors.centerIn: parent
                    icon: "hide_image"
                    iconSize: 22
                    color: tile.selected ? Colors.m3primary : Colors.m3onSurfaceVariant
                }
                StateLayer {
                    onClicked: root.picked(tile.modelData[0])
                }
            }
        }
    }

    StyledText {
        text: Translation.tr(root.currentName)
        font.pixelSize: Appearance.font.size.labelMedium
        color: Colors.m3onSurfaceVariant
    }
}
