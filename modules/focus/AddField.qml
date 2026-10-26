import QtQuick
import QtQuick.Layouts
import qs.common
import qs.common.widgets

// A text field with an add button; emits added(text) on Enter or the button, then clears.
Rectangle {
    id: root

    property string placeholder: ""
    signal added(string text)

    function submit() {
        if (field.text.trim() !== "")
            root.added(field.text);
        field.text = "";
    }

    Layout.fillWidth: true
    implicitHeight: 44
    radius: 22
    color: Colors.m3surfaceContainerHighest
    border.width: field.activeFocus ? 2 : 0
    border.color: Colors.m3primary

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 16
        anchors.rightMargin: 4
        spacing: 8

        TextInput {
            id: field
            Layout.fillWidth: true
            verticalAlignment: TextInput.AlignVCenter
            font.family: Appearance.font.main
            font.pixelSize: Appearance.font.size.bodyMedium
            color: Colors.m3onSurface
            clip: true
            selectByMouse: true
            onAccepted: root.submit()

            StyledText {
                anchors.fill: parent
                verticalAlignment: Text.AlignVCenter
                visible: field.text === ""
                text: root.placeholder
                color: Colors.m3outline
            }
        }
        IconButton {
            implicitWidth: 36
            implicitHeight: 36
            icon: "add"
            filled: field.text.trim() !== ""
            onClicked: root.submit()
        }
    }
}
