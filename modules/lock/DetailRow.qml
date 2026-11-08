import QtQuick
import QtQuick.Layouts
import qs.common
import qs.common.widgets

// One line of a Detail: a label and its value.
RowLayout {
    property string label
    property string value

    Layout.fillWidth: true
    visible: value !== ""
    spacing: Appearance.space.xl

    StyledText {
        text: parent.label
        color: Colors.m3onSurfaceVariant
        font.pixelSize: Appearance.font.size.labelMedium
    }
    Item { Layout.fillWidth: true }
    StyledText {
        text: parent.value
        font.pixelSize: Appearance.font.size.labelMedium
        font.weight: Font.Medium
    }
}
