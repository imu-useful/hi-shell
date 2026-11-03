import QtQuick
import qs.common
import qs.common.widgets

// A number that can be typed: Enter, or leaving the field, sets it. It's kept within [from, to] and
// rounded to `step`; a text that isn't a number puts the old value back.
Rectangle {
    id: root

    property real value: 0
    property real from: -100000
    property real to: 100000
    property real step: 1
    property int decimals: 0
    signal committed(real value)

    implicitWidth: 72
    implicitHeight: 32
    radius: 16
    color: input.activeFocus ? Colors.m3surfaceContainerHighest : "transparent"
    border.width: input.activeFocus ? 2 : 0
    border.color: Colors.m3primary

    function commit() {
        const typed = parseFloat(input.text.replace(",", "."));
        if (isNaN(typed))
            return;
        const rounded = Math.round(typed / root.step) * root.step;
        root.committed(Math.min(root.to, Math.max(root.from, +rounded.toFixed(4))));
    }

    // Follows the value while it isn't being typed in.
    Binding {
        target: input
        property: "text"
        value: root.value.toFixed(root.decimals)
        when: !input.activeFocus
    }

    TextInput {
        id: input
        anchors.fill: parent
        anchors.leftMargin: 8
        anchors.rightMargin: 8
        horizontalAlignment: TextInput.AlignHCenter
        verticalAlignment: TextInput.AlignVCenter
        font.family: Appearance.font.main
        font.pixelSize: Appearance.font.size.bodyMedium
        font.features: { "tnum": 1 }
        color: Colors.m3onSurface
        selectByMouse: true
        clip: true
        onAccepted: {
            root.commit();
            focus = false;
        }
        onActiveFocusChanged: if (!activeFocus) root.commit()
    }
}
