import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.common
import qs.common.widgets
import qs.services

// The keybinds of the Hyprland config, changed here instead of in the files: all of them, hi-shell's
// own and yours (services/Keybinds.qml finds every `hl.bind("KEYS", ...)` line). Change the keys (typed,
// or recorded with the keyboard button), the command (when it's a plain one) or the description, switch
// one off (the lines are commented out) or delete it; new ones go into ~/.config/hi-shell/binds.lua.
//
// The page is a list as tall as the settings window, and only the rows in view are made: with 130 keybinds,
// a card of a dozen items each, building them all at once made the page crawl. The top part (notes,
// adding, search) is the list's header and scrolls with it.
ListView {
    id: root

    // Set by Settings: the height of the window's page area.
    property real viewHeight: 600
    // What the search matches; `typed` is what's in the field, `query` follows a moment after the typing stops.
    property string query: ""
    property string typed: ""
    readonly property var shown: Keybinds.entries.filter(e => {
        const q = root.query.trim().toLowerCase();
        return q === "" || `${e.keys} ${e.desc} ${e.cmd ?? e.action} ${e.rel}`.toLowerCase().includes(q);
    })
    // How many enabled binds have each keys (binds inside a submap or function are left out).
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

    implicitHeight: viewHeight
    clip: true
    spacing: 8
    cacheBuffer: 600
    boundsBehavior: Flickable.StopAtBounds
    model: shown

    Component.onCompleted: Keybinds.refresh()

    // Smooth wheel scrolling and a thin scrollbar, like StyledFlickable's (a list with a header
    // starts at a negative contentY, so the bounds come from originY).
    property real targetY: 0
    readonly property real minY: root.originY
    readonly property real maxY: Math.max(root.originY, root.originY + root.contentHeight - root.height)

    ScrollBar.vertical: ScrollBar {
        policy: ScrollBar.AsNeeded
        contentItem: Rectangle {
            implicitWidth: 4
            radius: 2
            color: Colors.m3outline
            opacity: parent.active ? 0.8 : 0
            Behavior on opacity { EffectAnim {} }
        }
    }

    WheelHandler {
        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
        onWheel: event => {
            if (event.pixelDelta.y !== 0) {
                wheelScroll.stop();
                root.contentY = Math.max(root.minY, Math.min(root.maxY, root.contentY - event.pixelDelta.y));
                return;
            }
            const base = wheelScroll.running ? root.targetY : root.contentY;
            root.targetY = Math.max(root.minY, Math.min(root.maxY, base - event.angleDelta.y / 120 * 120));
            wheelScroll.restart();
        }
    }

    NumberAnimation {
        id: wheelScroll
        target: root
        property: "contentY"
        to: root.targetY
        duration: Appearance.anim.normal
        easing.type: Easing.OutCubic
    }

    Timer {
        id: searchTimer
        interval: 150
        onTriggered: root.query = root.typed
    }

    // A plain one-line field.
    component PlainField: Rectangle {
        id: pf

        property string value: ""
        property string placeholder: ""
        property bool readOnly: false
        property bool mono: false
        property alias input: input
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

    // --- Notes, adding a keybind, search ---
    header: Item {
        width: root.width
        height: headerColumn.implicitHeight + 16

        ColumnLayout {
            id: headerColumn
            width: parent.width
            spacing: 8

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
                    id: search
                    Layout.fillWidth: true
                    placeholder: Translation.tr("Search keybinds…")
                    onEdited: text => {
                        root.typed = text;
                        root.query = text;
                    }
                    // Filters as you type, a moment after the typing stops.
                    Component.onCompleted: input.textChanged.connect(() => {
                        root.typed = input.text;
                        searchTimer.restart();
                    })
                }
                StyledText {
                    Layout.leftMargin: 16
                    visible: Keybinds.entries.length > 0
                    text: Translation.tr("%1 of %2").arg(root.shown.length).arg(Keybinds.total)
                    color: Colors.m3outline
                    font.pixelSize: Appearance.font.size.labelMedium
                }
            }
        }
    }

    // --- One keybind ---
    delegate: Rectangle {
        id: card

        required property var modelData
        readonly property bool conflict: modelData.enabled && !modelData.nested && (root.counts[root.normal(modelData.keys)] ?? 0) > 1

        width: ListView.view.width
        height: body.implicitHeight + 20
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

    footer: ColumnLayout {
        width: root.width

        StyledText {
            Layout.fillWidth: true
            Layout.leftMargin: 16
            Layout.topMargin: 8
            visible: Keybinds.entries.length === 0 && Keybinds.exists
            text: Translation.tr("No keybinds found yet")
            color: Colors.m3onSurfaceVariant
        }
        StyledText {
            Layout.fillWidth: true
            Layout.leftMargin: 16
            Layout.topMargin: 8
            visible: Keybinds.total > Keybinds.entries.length
            text: Translation.tr("%1 more not shown").arg(Keybinds.total - Keybinds.entries.length)
            color: Colors.m3onSurfaceVariant
        }
        Item { implicitHeight: 12 }
    }
}
