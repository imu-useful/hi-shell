import QtQuick
import QtQuick.Layouts
import qs.common
import qs.common.widgets
import qs.services

// The keybinds of the Hyprland config, changed here instead of in the files: all of them, hi-shell's
// own and yours (services/Keybinds.qml finds every `hl.bind("KEYS", ...)` line). Change the keys (typed,
// or recorded with the keyboard button), the command (when it's a plain one) or the description, switch
// one off (the lines are commented out) or delete it; new ones go into ~/.config/hi-shell/binds.lua.
ColumnLayout {
    id: root

    property string query: ""
    readonly property var shown: Keybinds.entries.filter(e => {
        const q = root.query.trim().toLowerCase();
        return q === "" || `${e.keys} ${e.desc} ${e.cmd ?? e.action} ${e.rel}`.toLowerCase().includes(q);
    })
    // Keys more than one enabled bind has (binds inside a submap or function are left out).
    readonly property var counts: {
        const c = {};
        for (const e of Keybinds.entries) {
            if (e.enabled && !e.nested) {
                const k = root.normal(e.keys);
                c[k] = (c[k] ?? 0) + 1;
            }
        }
        return c;
    }

    function normal(keys) {
        return keys.toLowerCase().replace(/\s+/g, "");
    }

    spacing: 24

    Component.onCompleted: Keybinds.refresh()

    // A plain one-line field.
    component PlainField: Rectangle {
        id: pf

        property string value: ""
        property string placeholder: ""
        property bool readOnly: false
        property bool mono: false
        signal edited(string text)

        implicitHeight: 36
        radius: 18
        color: Colors.m3surfaceContainerHighest
        opacity: readOnly ? 0.7 : 1
        border.width: input.activeFocus ? 2 : 0
        border.color: Colors.m3primary

        TextInput {
            id: input
            anchors.fill: parent
            anchors.leftMargin: 14
            anchors.rightMargin: 14
            verticalAlignment: TextInput.AlignVCenter
            text: pf.value
            readOnly: pf.readOnly
            font.family: pf.mono ? Appearance.font.mono : Appearance.font.main
            font.pixelSize: pf.mono ? Appearance.font.size.labelMedium : Appearance.font.size.bodyMedium
            color: Colors.m3onSurface
            clip: true
            selectByMouse: true
            onAccepted: {
                pf.edited(text.trim());
                focus = false;
            }
            onActiveFocusChanged: if (!activeFocus && text.trim() !== pf.value && !pf.readOnly) pf.edited(text.trim())

            StyledText {
                anchors.fill: parent
                visible: input.text === ""
                text: pf.placeholder
                color: Colors.m3outline
                elide: Text.ElideRight
            }
        }
    }

    Section {
        icon: "keyboard"
        title: Translation.tr("Keybinds")

        ListRow {
            Layout.fillWidth: true
            icon: "info"
            title: Translation.tr("Shortcuts of your Hyprland config")
            subtitle: Translation.tr("Changed in the files in place (a copy of each is kept); new ones go to ~/.config/hi-shell/binds.lua. Applies after a Hyprland reload.")
        }
        ListRow {
            Layout.fillWidth: true
            visible: !Keybinds.exists
            icon: "folder_off"
            title: Translation.tr("No Hyprland folder at %1").arg(Keybinds.hyprDir.replace(Paths.home, "~"))
            subtitle: Translation.tr("Your Hyprland config is somewhere else, so its keybinds can't be listed; the ones added here still go to binds.lua.")
        }
        ListRow {
            Layout.fillWidth: true
            visible: Keybinds.exists && !Keybinds.loaded
            icon: "warning"
            title: Translation.tr("hi-shell isn't loaded from your Hyprland config")
            subtitle: Translation.tr("Keybinds added here won't work until it is: run install.sh again (or add the line it shows to your config).")
        }
        StyledText {
            Layout.fillWidth: true
            Layout.leftMargin: 16
            Layout.rightMargin: 16
            visible: Keybinds.error !== ""
            wrapMode: Text.Wrap
            text: Keybinds.error
            color: Colors.m3error
        }

        // Add a keybind.
        Rectangle {
            Layout.fillWidth: true
            implicitHeight: addColumn.implicitHeight + 24
            radius: Appearance.rounding.medium
            color: Colors.m3surfaceContainerLow

            ColumnLayout {
                id: addColumn
                anchors.fill: parent
                anchors.margins: 12
                spacing: 8

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8
                    MaterialIcon {
                        icon: "add"
                    }
                    KeysField {
                        id: newKeys
                        implicitWidth: 240
                        placeholder: Translation.tr("Keys, e.g. SUPER + F1")
                        onEdited: keys => newKeys.value = keys
                    }
                    PlainField {
                        id: newCmd
                        Layout.fillWidth: true
                        placeholder: Translation.tr("Command, e.g. firefox")
                        onEdited: text => newCmd.value = text
                    }
                }
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8
                    Item { implicitWidth: 24 }
                    PlainField {
                        id: newDesc
                        Layout.fillWidth: true
                        placeholder: Translation.tr("Description (optional)")
                        onEdited: text => newDesc.value = text
                    }
                    M3Button {
                        text: Translation.tr("Add")
                        icon: "add"
                        enabled: newKeys.value.trim() !== "" && newCmd.value.trim() !== ""
                        onClicked: {
                            Keybinds.add(newKeys.value.trim(), newCmd.value.trim(), newDesc.value.trim());
                            newKeys.value = newCmd.value = newDesc.value = "";
                        }
                    }
                }
            }
        }

        // Search.
        PlainField {
            Layout.fillWidth: true
            placeholder: Translation.tr("Search keybinds…")
            onEdited: text => root.query = text
            // Filters as you type, not only at Enter.
            Component.onCompleted: input.textChanged.connect(() => root.query = input.text)
        }
        StyledText {
            Layout.leftMargin: 16
            visible: Keybinds.entries.length > 0
            text: Translation.tr("%1 of %2").arg(root.shown.length).arg(Keybinds.total)
            color: Colors.m3outline
            font.pixelSize: Appearance.font.size.labelMedium
        }

        Repeater {
            model: root.shown

            Rectangle {
                id: card

                required property var modelData
                readonly property bool conflict: modelData.enabled && !modelData.nested && (root.counts[root.normal(modelData.keys)] ?? 0) > 1

                Layout.fillWidth: true
                implicitHeight: body.implicitHeight + 20
                radius: Appearance.rounding.medium
                color: Colors.m3surfaceContainer
                opacity: modelData.enabled ? 1 : 0.6

                ColumnLayout {
                    id: body
                    anchors.fill: parent
                    anchors.margins: 10
                    spacing: 6

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8

                        KeysField {
                            implicitWidth: 240
                            value: card.modelData.keys
                            readOnly: card.modelData.readonly
                            onEdited: keys => {
                                if (keys !== card.modelData.keys)
                                    Keybinds.setKeys(card.modelData, keys);
                            }
                        }
                        PlainField {
                            Layout.fillWidth: true
                            value: card.modelData.desc
                            placeholder: Translation.tr("No description")
                            // Only a description that's in the file can be changed.
                            readOnly: card.modelData.readonly || card.modelData.desc === ""
                            opacity: readOnly && card.modelData.desc === "" ? 0.5 : 1
                            onEdited: text => {
                                if (text !== "" && text !== card.modelData.desc)
                                    Keybinds.setDescription(card.modelData, text);
                            }
                        }
                        M3Switch {
                            enabled: !card.modelData.readonly
                            checked: card.modelData.enabled
                            onToggled: checked => Keybinds.setEnabled(card.modelData, checked)
                        }
                        IconButton {
                            enabled: !card.modelData.readonly
                            icon: "delete"
                            tooltip: Translation.tr("Delete")
                            onClicked: Keybinds.remove(card.modelData)
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8

                        // A plain command can be changed; any other action is shown as the code it is.
                        PlainField {
                            Layout.fillWidth: true
                            value: card.modelData.cmd ?? card.modelData.action
                            mono: card.modelData.cmd === null
                            readOnly: card.modelData.readonly || card.modelData.cmd === null
                            onEdited: text => {
                                if (text !== "" && text !== card.modelData.cmd)
                                    Keybinds.setCommand(card.modelData, text);
                            }
                        }
                        // The same keys on another enabled bind: both run.
                        StyledText {
                            visible: card.conflict
                            text: Translation.tr("also bound elsewhere")
                            color: Colors.m3error
                            font.pixelSize: Appearance.font.size.labelSmall
                        }
                        StyledText {
                            text: `${card.modelData.own ? "binds.lua" : card.modelData.rel}:${card.modelData.line}${card.modelData.readonly ? " · " + (card.modelData.why === "symlink" ? Translation.tr("a symlink: change its target") : Translation.tr("not writable")) : ""}`
                            color: Colors.m3outline
                            font.pixelSize: Appearance.font.size.labelSmall
                        }
                    }
                }
            }
        }

        StyledText {
            Layout.fillWidth: true
            Layout.leftMargin: 16
            visible: Keybinds.entries.length === 0 && Keybinds.exists
            text: Translation.tr("No keybinds found yet")
            color: Colors.m3onSurfaceVariant
        }
        StyledText {
            Layout.fillWidth: true
            Layout.leftMargin: 16
            visible: Keybinds.total > Keybinds.entries.length
            text: Translation.tr("%1 more not shown").arg(Keybinds.total - Keybinds.entries.length)
            color: Colors.m3onSurfaceVariant
        }
    }
}
