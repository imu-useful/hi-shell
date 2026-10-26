import QtQuick
import QtQuick.Layouts
import qs.common
import qs.common.widgets

// Closable chips for a list of strings, or a hint when it's empty; emits removed(value).
Flow {
    id: root

    property var items: []
    property string icon: ""
    property string emptyText: ""
    signal removed(string value)

    Layout.fillWidth: true
    Layout.margins: 10
    spacing: 8

    StyledText {
        visible: root.items.length === 0
        text: root.emptyText
        color: Colors.m3onSurfaceVariant
        font.pixelSize: Appearance.font.size.labelMedium + 1
    }
    Repeater {
        model: root.items
        Chip {
            required property string modelData
            text: modelData
            icon: root.icon
            closable: true
            onCloseClicked: root.removed(modelData)
        }
    }
}
