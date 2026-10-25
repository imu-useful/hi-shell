import QtQuick
import QtQuick.Layouts
import qs.common.widgets

// Row with a segmented button. `options`: [{ value, text, icon? }]; emits selected(value).
ListRow {
    id: root

    property var options: []
    property var value
    signal selected(var value)

    Layout.fillWidth: true

    SegmentedButton {
        model: root.options.map(o => ({ text: o.text, icon: o.icon ?? "" }))
        currentIndex: Math.max(0, root.options.findIndex(o => o.value === root.value))
        onSelected: index => root.selected(root.options[index].value)
    }
}
