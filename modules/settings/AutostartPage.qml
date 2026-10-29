import QtQuick
import QtQuick.Layouts
import qs.common
import qs.common.widgets
import qs.services

// Commands Hyprland runs when it starts, like `exec-once` lines, edited here instead of in the
// config: add, change, switch off, delete, or start one now. Kept in Config hyprland.autostart
// and written into ~/.config/hi-shell/hyprland.lua (HyprlandSettings), which Hyprland loads.
ColumnLayout {
    id: root

    readonly property var entries: Config.options.hyprland.autostart ?? []

    spacing: 24

    function change(index, patch) {
        HyprlandSettings.setAutostart(root.entries.map((e, i) => i === index ? Object.assign({}, e, patch) : e));
    }

    function remove(index) {
        HyprlandSettings.setAutostart(root.entries.filter((_, i) => i !== index));
    }

    function add(cmd) {
        const text = cmd.trim();
        if (text !== "")
            HyprlandSettings.setAutostart([...root.entries, { cmd: text, enabled: true }]);
    }

    Section {
        icon: "rocket_launch"
        title: Translation.tr("Autostart")

        ListRow {
            Layout.fillWidth: true
            icon: "info"
            title: Translation.tr("Run when Hyprland starts")
            subtitle: Translation.tr("Like exec-once: runs once at Hyprland's start (▶ runs it now). Lines from your own config aren't listed.")
        }

        Repeater {
            model: root.entries

            TextRow {
                id: row

                required property var modelData
                required property int index

                icon: "terminal"
                title: row.modelData.enabled ? Translation.tr("Command") : Translation.tr("Command (off)")
                value: row.modelData.cmd ?? ""
                placeholder: Translation.tr("e.g. discord --start-minimized")
                fieldWidth: 320
                // An emptied field removes the entry.
                onEdited: text => text.trim() === "" ? root.remove(row.index) : root.change(row.index, { cmd: text.trim() })

                M3Switch {
                    checked: row.modelData.enabled
                    onToggled: checked => root.change(row.index, { enabled: checked })
                }
                IconButton {
                    icon: "play_arrow"
                    tooltip: Translation.tr("Run now")
                    onClicked: HyprlandSettings.runNow(row.modelData.cmd)
                }
                IconButton {
                    icon: "delete"
                    tooltip: Translation.tr("Delete")
                    onClicked: root.remove(row.index)
                }
            }
        }

        ListRow {
            id: addRow

            Layout.fillWidth: true
            icon: "add"
            title: Translation.tr("Add a command")

            Rectangle {
                implicitWidth: 320
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
                        root.add(text);
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
                    root.add(field.text);
                    field.text = "";
                }
            }
        }
    }
}
