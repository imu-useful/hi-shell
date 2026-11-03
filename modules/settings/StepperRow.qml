import QtQuick
import QtQuick.Layouts
import qs.common
import qs.common.widgets

// Row with − value + buttons; emits changed(value) within [from, to].
ListRow {
    id: root

    property real value: 0
    property real step: 1
    property real from: -100000
    property real to: 100000
    property int decimals: 0
    signal changed(real value)

    Layout.fillWidth: true

    IconButton {
        implicitWidth: 34
        implicitHeight: 34
        icon: "remove"
        enabled: root.value > root.from
        onClicked: root.changed(Math.max(root.from, +(root.value - root.step).toFixed(4)))
    }
    NumberField {
        Layout.preferredWidth: 72
        value: root.value
        from: root.from
        to: root.to
        step: root.step
        decimals: root.decimals
        onCommitted: v => root.changed(v)
    }
    IconButton {
        implicitWidth: 34
        implicitHeight: 34
        icon: "add"
        enabled: root.value < root.to
        onClicked: root.changed(Math.min(root.to, +(root.value + root.step).toFixed(4)))
    }
}
