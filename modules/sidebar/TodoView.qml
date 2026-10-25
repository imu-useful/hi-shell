import QtQuick
import QtQuick.Layouts
import qs.common
import qs.common.widgets
import qs.services

// To-do list: type and press Enter to add, tap the circle to complete.
ColumnLayout {
    id: root

    spacing: 8

    Rectangle {
        Layout.fillWidth: true
        implicitHeight: 44
        radius: 22
        color: Colors.m3surfaceContainerHighest

        TextInput {
            id: input
            anchors.fill: parent
            anchors.leftMargin: 18
            anchors.rightMargin: 48
            verticalAlignment: TextInput.AlignVCenter
            font.family: Appearance.font.main
            font.pixelSize: Appearance.font.size.bodyMedium
            color: Colors.m3onSurface
            clip: true
            onAccepted: {
                Todo.add(text);
                text = "";
            }

            StyledText {
                anchors.fill: parent
                visible: input.text === ""
                text: "Add a task"
                color: Colors.m3outline
            }
        }
        IconButton {
            anchors.right: parent.right
            anchors.rightMargin: 4
            anchors.verticalCenter: parent.verticalCenter
            implicitWidth: 36
            implicitHeight: 36
            icon: "add"
            filled: input.text !== ""
            onClicked: input.accepted()
        }
    }

    StyledFlickable {
        Layout.fillWidth: true
        Layout.fillHeight: true
        contentHeight: list.implicitHeight

        ColumnLayout {
            id: list
            width: parent.width
            spacing: 6

            StyledText {
                visible: Todo.items.length === 0
                Layout.alignment: Qt.AlignHCenter
                Layout.topMargin: 30
                text: "No tasks"
                color: Colors.m3onSurfaceVariant
            }

            Repeater {
                model: Todo.items

                Rectangle {
                    required property var modelData
                    required property int index

                    Layout.fillWidth: true
                    implicitHeight: 48
                    radius: Appearance.rounding.large
                    color: modelData.done ? Colors.m3surfaceContainer : Colors.m3secondaryContainer

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 8
                        anchors.rightMargin: 4
                        spacing: 8

                        IconButton {
                            implicitWidth: 36
                            implicitHeight: 36
                            icon: modelData.done ? "check_circle" : "radio_button_unchecked"
                            iconColor: modelData.done ? Colors.m3primary : Colors.m3onSecondaryContainer
                            onClicked: Todo.toggle(index)
                        }
                        StyledText {
                            Layout.fillWidth: true
                            text: modelData.text
                            font.strikeout: modelData.done
                            color: modelData.done ? Colors.m3onSurfaceVariant : Colors.m3onSecondaryContainer
                        }
                        IconButton {
                            implicitWidth: 36
                            implicitHeight: 36
                            icon: "delete"
                            onClicked: Todo.remove(index)
                        }
                    }
                }
            }

            Chip {
                visible: Todo.items.some(i => i.done)
                Layout.alignment: Qt.AlignRight
                icon: "done_all"
                text: "Clear completed"
                onClicked: Todo.clearDone()
            }
        }
    }
}
