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
    StyledText {
        Layout.preferredWidth: 60
        horizontalAlignment: Text.AlignHCenter
        text: root.value.toFixed(root.decimals)
        font.features: { "tnum": 1 }
    }
    IconButton {
        implicitWidth: 34
        implicitHeight: 34
        icon: "add"
        enabled: root.value < root.to
        onClicked: root.changed(Math.min(root.to, +(root.value + root.step).toFixed(4)))
    }
}
