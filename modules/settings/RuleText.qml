import QtQuick
import qs.common
import qs.common.widgets

// A small text field of the rule editor: Enter or leaving it emits edited(text).
Rectangle {
    id: root

    property string value: ""
    property string placeholder: ""
    property bool mono: false
    signal edited(string text)

    implicitWidth: 160
    implicitHeight: 36
    radius: 18
    color: Colors.m3surfaceContainerHighest
    border.width: field.activeFocus ? 2 : 0
    border.color: Colors.m3primary

    TextInput {
        id: field
        anchors.fill: parent
        anchors.leftMargin: 14
        anchors.rightMargin: 14
        verticalAlignment: TextInput.AlignVCenter
        text: root.value
        font.family: root.mono ? Appearance.font.mono : Appearance.font.main
        font.pixelSize: Appearance.font.size.bodyMedium
        color: Colors.m3onSurface
        clip: true
        selectByMouse: true
        onAccepted: {
            root.edited(text);
            focus = false;
        }
        onActiveFocusChanged: if (!activeFocus && text !== root.value) root.edited(text)

        StyledText {
            anchors.fill: parent
            verticalAlignment: Text.AlignVCenter
            visible: field.text === "" && !field.activeFocus
            text: root.placeholder
            color: Colors.m3outline
            elide: Text.ElideRight
        }
    }
}
