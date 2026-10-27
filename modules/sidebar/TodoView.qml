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
                text: Translation.tr("Add a task")
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
                text: Translation.tr("No tasks")
                color: Colors.m3onSurfaceVariant
            }

            Repeater {
                model: Todo.items

                Rectangle {
                    id: task
                    required property var modelData
                    required property int index

                    // Erase animation (EraseAnim): slides away and fades, then the row folds.
                    property real leave: 0
                    property real collapse: 1
                    readonly property var eraseDelay: Todo.erasing[modelData.time]
                    onEraseDelayChanged: {
                        if (eraseDelay !== undefined && !eraser.running) {
                            eraser.delay = eraseDelay;
                            eraser.start();
                        }
                    }
                    EraseAnim {
                        id: eraser
                        target: task
                    }

                    Layout.fillWidth: true
                    implicitHeight: 48 * collapse
                    clip: leave > 0
                    opacity: 1 - leave
                    transform: Translate { x: task.leave * task.width * 0.5 }
                    radius: Appearance.rounding.large
                    color: modelData.done ? Colors.m3surfaceContainer : Colors.m3secondaryContainer

                    RowLayout {
                        anchors.top: parent.top
                        anchors.left: parent.left
                        anchors.right: parent.right
                        height: 48
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
                            onClicked: Todo.erase([modelData.time])
                        }
                    }
                }
            }

            Chip {
                visible: Todo.items.some(i => i.done)
                Layout.alignment: Qt.AlignRight
                icon: "done_all"
                text: Translation.tr("Clear completed")
                onClicked: Todo.eraseDone()
            }
        }
    }
}
