import QtQuick
import QtQuick.Layouts
import qs.common

// Connected button group: one outlined strip split by hairlines, the selected segment filled with the accent.
// `model`: list of strings or { text, icon } objects.
RowLayout {
    id: root

    property var model: []
    property int currentIndex: 0

    signal selected(int index)

    // Neighbours share their edge: each one's outline lies over the last one's.
    spacing: -Appearance.edge

    Repeater {
        model: root.model

        Rectangle {
            id: segment

            required property var modelData
            required property int index

            readonly property bool active: index === root.currentIndex
            readonly property string label: typeof modelData === "string" ? modelData : modelData.text ?? ""
            readonly property string glyph: typeof modelData === "string" ? "" : modelData.icon ?? ""
            readonly property real outer: Appearance.shape.button
            readonly property color contentColor: active ? Colors.m3onPrimary : layer.containsMouse ? Colors.m3primary : Colors.m3onSurfaceVariant

            Layout.fillWidth: true
            implicitHeight: 32
            implicitWidth: content.implicitWidth + 24
            // Over its neighbours' edges while selected, so the accent edge isn't cut by theirs.
            z: active ? 1 : 0
            topLeftRadius: index === 0 ? outer : 0
            bottomLeftRadius: index === 0 ? outer : 0
            topRightRadius: index === root.model.length - 1 ? outer : 0
            bottomRightRadius: index === root.model.length - 1 ? outer : 0
            color: active ? Colors.m3primary : "transparent"
            border.width: Appearance.edge
            border.color: active ? Colors.m3primary : Colors.m3outlineVariant

            Behavior on color { ColorAnim {} }

            RowLayout {
                id: content
                anchors.centerIn: parent
                spacing: 6

                MaterialIcon {
                    visible: segment.glyph !== ""
                    icon: segment.glyph
                    iconSize: 16
                    color: segment.contentColor
                }

                StyledText {
                    visible: segment.label !== ""
                    text: segment.label
                    font.pixelSize: Appearance.font.size.labelMedium
                    font.weight: Font.Medium
                    color: segment.contentColor
                }
            }

            StateLayer {
                id: layer
                tint: segment.contentColor
                topLeftRadius: segment.topLeftRadius
                topRightRadius: segment.topRightRadius
                bottomLeftRadius: segment.bottomLeftRadius
                bottomRightRadius: segment.bottomRightRadius
                onClicked: {
                    root.currentIndex = segment.index;
                    root.selected(segment.index);
                }
            }
        }
    }
}
