import QtQuick
import QtQuick.Layouts
import qs.common
import qs.common.widgets
import qs.services
import qs.modules.settings

// How a session can end: any time, when the timer runs out, or when the tasks are done.
ColumnLayout {
    id: root

    readonly property int picked: Todo.items.filter(i => Focus.isSessionTask(i) && !i.done).length

    spacing: 20

    Section {
        icon: "logout"
        title: Translation.tr("Exit condition")

        Repeater {
            model: [
                { value: "manual", icon: "stop_circle", title: Translation.tr("Manual"),
                  text: Translation.tr("A Stop button ends the session whenever you want.") },
                { value: "timer", icon: "hourglass_bottom", title: Translation.tr("Timer"),
                  text: Translation.tr("No Stop button: the session ends when all the Pomodoro cycles are over.") },
                { value: "tasks", icon: "task_alt", title: Translation.tr("Tasks"),
                  text: Translation.tr("No Stop button: the session ends once every task picked for it is done.") }
            ]

            Rectangle {
                id: option
                required property var modelData
                readonly property bool selected: Focus.profile.exit === modelData.value

                Layout.fillWidth: true
                implicitHeight: row.implicitHeight + 28
                radius: Appearance.rounding.medium
                color: selected ? Colors.m3secondaryContainer : "transparent"
                Behavior on color { ColorAnim {} }

                RowLayout {
                    id: row
                    anchors.fill: parent
                    anchors.leftMargin: 16
                    anchors.rightMargin: 16
                    spacing: 14

                    MaterialIcon {
                        icon: option.modelData.icon
                        fill: option.selected ? 1 : 0
                        color: option.selected ? Colors.m3onSecondaryContainer : Colors.m3onSurfaceVariant
                    }
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 2
                        StyledText {
                            text: option.modelData.title
                            font.weight: Font.Medium
                            color: option.selected ? Colors.m3onSecondaryContainer : Colors.m3onSurface
                        }
                        StyledText {
                            Layout.fillWidth: true
                            text: option.modelData.text
                            wrapMode: Text.WordWrap
                            font.pixelSize: Appearance.font.size.labelMedium + 1
                            color: option.selected ? Colors.m3onSecondaryContainer : Colors.m3onSurfaceVariant
                        }
                    }
                    MaterialIcon {
                        icon: option.selected ? "radio_button_checked" : "radio_button_unchecked"
                        color: option.selected ? Colors.m3primary : Colors.m3outline
                    }
                }
                StateLayer {
                    onClicked: Focus.set("exit", option.modelData.value)
                }
            }
        }
    }

    // Tasks mode with nothing to do couldn't end, so say so.
    ListRow {
        Layout.fillWidth: true
        visible: Focus.profile.exit === "tasks"
        icon: root.picked ? "checklist" : "warning"
        title: root.picked ? Translation.trn("%1 task picked for the session", "%1 tasks picked for the session", root.picked)
                           : Translation.tr("No tasks picked for the session yet")
        subtitle: Translation.tr("Pick them on the To-Do tab.")
        color: root.picked ? Colors.m3surfaceContainer : Colors.m3errorContainer
    }
}
