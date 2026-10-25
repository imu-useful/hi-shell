import QtQuick
import QtQuick.Layouts
import qs.common.widgets

// Row with a switch; emits toggled(checked).
ListRow {
    id: root

    property bool checked: false
    signal toggled(bool checked)

    Layout.fillWidth: true
    clickable: true
    onClicked: root.toggled(!root.checked)

    M3Switch {
        checked: root.checked
        onToggled: checked => root.toggled(checked)
    }
}
