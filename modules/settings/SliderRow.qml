import QtQuick
import QtQuick.Layouts
import qs.common
import qs.common.widgets

// Row with a slider over [from, to], rounded to `step`; emits moved(value).
ListRow {
    id: root

    property real value: 0
    property real from: 0
    property real to: 1
    property real step: 1
    property string suffix: ""
    property int decimals: 0
    signal moved(real value)

    Layout.fillWidth: true

    M3Slider {
        implicitWidth: 220
        implicitHeight: 32
        value: (root.value - root.from) / (root.to - root.from)
        onMoved: v => {
            const raw = root.from + v * (root.to - root.from);
            root.moved(Math.round(raw / root.step) * root.step);
        }
    }
    NumberField {
        Layout.preferredWidth: 72
        value: root.value
        from: root.from
        to: root.to
        step: root.step
        decimals: root.decimals
        onCommitted: v => root.moved(v)
    }
    StyledText {
        visible: root.suffix !== ""
        text: root.suffix
        color: Colors.m3onSurfaceVariant
    }
}
