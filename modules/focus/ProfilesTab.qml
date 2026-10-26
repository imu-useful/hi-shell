import QtQuick
import QtQuick.Layouts
import qs.common
import qs.common.widgets
import qs.services
import qs.modules.settings

// Profiles: pick one to edit and use it (the other tabs show the active profile). Study
// and Work are built in and can be reset; your own ones get a name and an icon, start
// blank or as a copy of the active one, and can be changed or deleted.
ColumnLayout {
    id: root

    property string newIcon: Focus.icons[0]

    readonly property var exitNames: ({
        manual: Translation.tr("Manual exit"),
        timer: Translation.tr("Ends with the timer"),
        tasks: Translation.tr("Ends with the tasks")
    })

    function summary(p) {
        const t = p.timer, l = p.lists, items = l[l.mode];
        const blocked = items.apps.length + items.sites.length;
        return [
            Translation.tr("%1/%2/%3 min × %4").arg(t.focus).arg(t.shortBreak).arg(t.longBreak).arg(t.cycles),
            exitNames[p.exit] ?? "",
            l.mode === "whitelist" ? Translation.trn("%1 allowed", "%1 allowed", blocked) : Translation.trn("%1 blocked", "%1 blocked", blocked)
        ].join(" · ");
    }

    // Built-in names are translated; your own are shown as written.
    function displayName(p) {
        return p.builtin ? Translation.tr(p.name) : p.name;
    }

    spacing: 20

    Section {
        icon: "bookmarks"
        title: Translation.tr("Profiles")

        Repeater {
            model: Focus.profileIds

            Rectangle {
                id: card
                required property string modelData
                readonly property var profile: Focus.profiles[modelData]
                readonly property bool active: Focus.activeId === modelData

                Layout.fillWidth: true
                implicitHeight: 68
                radius: Appearance.rounding.medium
                color: active ? Colors.m3secondaryContainer : "transparent"
                Behavior on color { ColorAnim {} }

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 12
                    anchors.rightMargin: 16
                    spacing: 14

                    Rectangle {
                        implicitWidth: 44
                        implicitHeight: 44
                        radius: card.active ? 14 : 22
                        color: card.active ? Colors.m3primary : Colors.m3surfaceContainerHighest
                        Behavior on radius { SpringAnim {} }
                        MaterialIcon {
                            anchors.centerIn: parent
                            icon: card.profile.icon
                            fill: card.active ? 1 : 0
                            color: card.active ? Colors.m3onPrimary : Colors.m3onSurfaceVariant
                        }
                    }
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 2
                        StyledText {
                            text: root.displayName(card.profile)
                            font.weight: Font.Medium
                            color: card.active ? Colors.m3onSecondaryContainer : Colors.m3onSurface
                        }
                        StyledText {
                            Layout.fillWidth: true
                            text: root.summary(card.profile)
                            elide: Text.ElideRight
                            font.pixelSize: Appearance.font.size.labelMedium
                            color: card.active ? Colors.m3onSecondaryContainer : Colors.m3onSurfaceVariant
                        }
                    }
                    MaterialIcon {
                        visible: card.active
                        icon: "check_circle"
                        fill: 1
                        color: Colors.m3primary
                    }
                }
                StateLayer {
                    onClicked: Focus.select(card.modelData)
                }
            }
        }
    }

    Section {
        icon: "add_circle"
        title: Translation.tr("New profile")

        AddField {
            Layout.margins: 6
            placeholder: Translation.tr("Name, e.g. Exams")
            onAdded: text => Focus.add(text, root.newIcon, copy.checked)
        }
        IconPicker {
            current: root.newIcon
            onPicked: icon => root.newIcon = icon
        }
        SwitchRow {
            id: copy
            icon: "content_copy"
            title: Translation.tr("Copy the active profile")
            subtitle: checked ? Translation.tr("Starts with the settings of “%1”").arg(root.displayName(Focus.profile))
                              : Translation.tr("Starts blank: 25/5/15 min × 4, empty lists, manual exit")
            onToggled: checked => copy.checked = checked
        }
    }

    Section {
        icon: "edit"
        title: Translation.tr("Active profile: %1").arg(root.displayName(Focus.profile))

        TextRow {
            visible: !Focus.profile.builtin
            icon: "badge"
            title: Translation.tr("Name")
            value: Focus.profile.name
            onEdited: text => Focus.update(Focus.activeId, { name: text })
        }
        ListRow {
            Layout.fillWidth: true
            visible: !Focus.profile.builtin
            icon: Focus.profile.icon
            title: Translation.tr("Icon")
        }
        IconPicker {
            visible: !Focus.profile.builtin
            Layout.topMargin: 0
            current: Focus.profile.icon
            onPicked: icon => Focus.update(Focus.activeId, { icon: icon })
        }
        ListRow {
            Layout.fillWidth: true
            visible: Focus.profile.builtin
            icon: "restart_alt"
            title: Translation.tr("Reset to defaults")
            subtitle: Translation.tr("Built-in profiles can't be deleted, only reset")
            clickable: true
            onClicked: Focus.reset(Focus.activeId)
        }
        ListRow {
            Layout.fillWidth: true
            visible: !Focus.profile.builtin
            icon: "delete"
            title: Translation.tr("Delete profile")
            clickable: true
            onClicked: Focus.remove(Focus.activeId)
        }
    }
}
