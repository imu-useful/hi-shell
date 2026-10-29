import QtQuick
import QtQuick.Layouts
import qs.common
import qs.common.widgets
import qs.services

// The commands Hyprland runs when it starts, like `exec-once` lines, edited here instead of in the
// config: all of them, the ones in your Hyprland files too (services/Autostart.qml finds the plain
// `hl.exec_cmd("...")` lines). Change one, switch it off (it's commented out), delete it or run it
// now; new ones go into ~/.config/hi-shell/exec.lua.
ColumnLayout {
    id: root

    spacing: 24

    Component.onCompleted: Autostart.refresh()

    Section {
        icon: "rocket_launch"
        title: Translation.tr("Autostart")

        ListRow {
            Layout.fillWidth: true
            icon: "info"
            title: Translation.tr("Run when Hyprland starts")
            subtitle: Translation.tr("Like exec-once: at the next start (▶ runs it now). Lines of your Hyprland files are changed in place; a copy of each file is kept.")
        }

        StyledText {
            Layout.fillWidth: true
            Layout.leftMargin: 16
            Layout.rightMargin: 16
            visible: Autostart.error !== ""
            wrapMode: Text.Wrap
            text: Autostart.error
            color: Colors.m3error
        }

        Repeater {
            model: Autostart.entries

            TextRow {
                id: row

                required property var modelData

                icon: modelData.own ? "rocket_launch" : "terminal"
                // Where it comes from, and when it runs.
                title: modelData.own ? Translation.tr("hi-shell (exec.lua)") : modelData.rel
                subtitle: `${modelData.kind === "start" ? Translation.tr("At start") : Translation.tr("On every reload")} · ${Translation.tr("line %1").arg(modelData.line)}`
                value: modelData.cmd
                fieldWidth: 360
                enabled: !modelData.readonly
                opacity: modelData.enabled ? 1 : 0.6
                // An emptied field removes the line.
                onEdited: text => {
                    if (text.trim() === "")
                        Autostart.remove(row.modelData);
                    else if (text.trim() !== row.modelData.cmd)
                        Autostart.edit(row.modelData, text.trim());
                }

                M3Switch {
                    checked: row.modelData.enabled
                    onToggled: checked => Autostart.setEnabled(row.modelData, checked)
                }
                IconButton {
                    icon: "play_arrow"
                    tooltip: Translation.tr("Run now")
                    onClicked: HyprlandSettings.runNow(row.modelData.cmd)
                }
                IconButton {
                    icon: "delete"
                    tooltip: Translation.tr("Delete")
                    onClicked: Autostart.remove(row.modelData)
                }
            }
        }

        StyledText {
            Layout.fillWidth: true
            Layout.leftMargin: 16
            visible: Autostart.entries.length === 0
            text: Translation.tr("No commands found yet")
            color: Colors.m3onSurfaceVariant
        }

        ListRow {
            id: addRow

            Layout.fillWidth: true
            icon: "add"
            title: Translation.tr("Add a command")
            subtitle: Translation.tr("Goes into ~/.config/hi-shell/exec.lua")

            Rectangle {
                implicitWidth: 360
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
                    font.family: Appearance.font.main
                    font.pixelSize: Appearance.font.size.bodyMedium
                    color: Colors.m3onSurface
                    clip: true
                    selectByMouse: true
                    onAccepted: {
                        if (text.trim() !== "")
                            Autostart.add(text.trim());
                        text = "";
                    }

                    StyledText {
                        anchors.fill: parent
                        visible: field.text === ""
                        text: Translation.tr("e.g. discord --start-minimized")
                        color: Colors.m3outline
                    }
                }
            }
            M3Button {
                text: Translation.tr("Add")
                icon: "add"
                enabled: field.text.trim() !== ""
                onClicked: {
                    Autostart.add(field.text.trim());
                    field.text = "";
                }
            }
        }
    }
}
