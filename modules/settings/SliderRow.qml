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
    StyledText {
        Layout.preferredWidth: 56
        horizontalAlignment: Text.AlignRight
        text: root.value.toFixed(root.decimals) + root.suffix
        font.features: { "tnum": 1 }
        color: Colors.m3onSurfaceVariant
    }
}
