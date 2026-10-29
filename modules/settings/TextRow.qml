import QtQuick
import QtQuick.Layouts
import qs.common
import qs.common.widgets

// Row with a text field; emits edited(text) on Enter or when focus leaves.
ListRow {
    id: root

    property string value: ""
    property string placeholder: ""
    property int fieldWidth: 240
    property bool secret: false
    property bool readOnly: false
    signal edited(string text)

    Layout.fillWidth: true

    Rectangle {
        implicitWidth: root.fieldWidth
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
            echoMode: root.secret && !activeFocus ? TextInput.Password : TextInput.Normal
            font.family: Appearance.font.main
            font.pixelSize: Appearance.font.size.bodyMedium
            color: Colors.m3onSurface
            clip: true
            selectByMouse: true
            readOnly: root.readOnly
            onAccepted: {
                root.edited(text);
                focus = false;
            }
            onActiveFocusChanged: if (!activeFocus && text !== root.value) root.edited(text)

            StyledText {
                anchors.fill: parent
                visible: field.text === ""
                text: root.placeholder
                color: Colors.m3outline
            }
        }
    }
}
