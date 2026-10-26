import QtQuick
import QtQuick.Layouts
import qs.common
import qs.common.widgets
import qs.services
import qs.modules.settings

// The shell's to-do list (the same one as in the sidebar); the pin picks a task for
// the session, which the Tasks exit condition waits for.
ColumnLayout {
    id: root

    spacing: 20

    Section {
        icon: "checklist"
        title: Translation.tr("To-Do")

        AddField {
            Layout.margins: 6
            placeholder: Translation.tr("New task for the session")
            onAdded: text => Focus.addTask(text)
        }

        StyledText {
            Layout.margins: 14
            visible: Todo.items.length === 0
            text: Translation.tr("No tasks. Added ones are picked for the session right away.")
            color: Colors.m3onSurfaceVariant
        }

        Repeater {
            model: Todo.items

            ListRow {
                id: task
                required property var modelData
                required property int index
                readonly property bool picked: Focus.isSessionTask(modelData)

                Layout.fillWidth: true
                title: modelData.text
                subtitle: picked ? Translation.tr("In this session") : ""
                clickable: true
                onClicked: Todo.toggle(index)

                // Pin: picks the task for the session.
                MaterialIcon {
                    icon: task.picked ? "push_pin" : "keep"
                    fill: task.picked ? 1 : 0
                    color: task.picked ? Colors.m3primary : Colors.m3outline
                    MouseArea {
                        anchors.fill: parent
                        anchors.margins: -8
                        cursorShape: Qt.PointingHandCursor
                        onClicked: Focus.setSessionTask(task.modelData, !task.picked)
                    }
                }
                IconButton {
                    implicitWidth: 34
                    implicitHeight: 34
                    icon: "delete"
                    onClicked: {
                        Focus.setSessionTask(task.modelData, false);
                        Todo.remove(task.index);
                    }
                }
                icon: modelData.done ? "check_box" : "check_box_outline_blank"
                opacity: modelData.done ? 0.6 : 1
            }
        }
    }

    ListRow {
        Layout.fillWidth: true
        visible: Todo.items.some(i => i.done)
        icon: "cleaning_services"
        title: Translation.tr("Clear completed")
        clickable: true
        onClicked: Todo.clearDone()
    }
}
