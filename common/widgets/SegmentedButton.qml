import QtQuick
import QtQuick.Layouts
import qs.common

// M3 Expressive connected button group: the selected segment becomes a pill.
// `model`: list of strings or { text, icon } objects.
RowLayout {
    id: root

    property var model: []
    property int currentIndex: 0

    signal selected(int index)

    spacing: 2

    Repeater {
        model: root.model

        Rectangle {
            id: segment

            required property var modelData
            required property int index

            readonly property bool active: index === root.currentIndex
            readonly property string label: typeof modelData === "string" ? modelData : modelData.text ?? ""
            readonly property string glyph: typeof modelData === "string" ? "" : modelData.icon ?? ""
            readonly property real outer: height / 2
            readonly property real inner: active ? height / 2 : Appearance.rounding.small
            readonly property color contentColor: active ? Colors.m3onSecondaryContainer : Colors.m3onSurfaceVariant

            Layout.fillWidth: true
            implicitHeight: 36
            implicitWidth: content.implicitWidth + 28
            topLeftRadius: index === 0 ? outer : inner
            bottomLeftRadius: index === 0 ? outer : inner
            topRightRadius: index === root.model.length - 1 ? outer : inner
            bottomRightRadius: index === root.model.length - 1 ? outer : inner
            color: active ? Colors.m3secondaryContainer : Colors.m3surfaceContainerHigh

            Behavior on color { ColorAnim {} }
            Behavior on topLeftRadius { SpatialAnim { duration: Appearance.anim.normal } }
            Behavior on bottomLeftRadius { SpatialAnim { duration: Appearance.anim.normal } }
            Behavior on topRightRadius { SpatialAnim { duration: Appearance.anim.normal } }
            Behavior on bottomRightRadius { SpatialAnim { duration: Appearance.anim.normal } }

            RowLayout {
                id: content
                anchors.centerIn: parent
                spacing: 6

                MaterialIcon {
                    visible: segment.glyph !== ""
                    icon: segment.glyph
                    iconSize: 18
                    fill: segment.active ? 1 : 0
                    color: segment.contentColor
                }

                StyledText {
                    visible: segment.label !== ""
                    text: segment.label
                    font.pixelSize: Appearance.font.size.labelMedium + 1
                    font.weight: Font.Medium
                    color: segment.contentColor
                }
            }

            StateLayer {
                tint: segment.contentColor
                onClicked: {
                    root.currentIndex = segment.index;
                    root.selected(segment.index);
                }
            }
        }
    }
}
