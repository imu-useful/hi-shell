import QtQuick
import QtQuick.Layouts
import qs.common
import qs.common.widgets
import qs.services
import qs.modules.settings

// Apps and sites a session blocks (blacklist) or the only ones it allows (whitelist).
// Each mode keeps its own lists, so switching back and forth loses nothing.
ColumnLayout {
    id: root

    readonly property bool whitelist: Focus.profile.lists.mode === "whitelist"
    readonly property var apps: Focus.listItems("apps")
    readonly property var sites: Focus.listItems("sites")

    spacing: 20

    Section {
        icon: "rule"
        title: Translation.tr("Mode")

        ChoiceRow {
            icon: root.whitelist ? "verified_user" : "block"
            title: root.whitelist ? Translation.tr("Whitelist") : Translation.tr("Blacklist")
            subtitle: root.whitelist ? Translation.tr("Only these apps and sites work during a session")
                                     : Translation.tr("These apps and sites are blocked during a session")
            value: Focus.profile.lists.mode
            options: [
                { value: "blacklist", text: Translation.tr("Block"), icon: "block" },
                { value: "whitelist", text: Translation.tr("Allow"), icon: "check" }
            ]
            onSelected: value => Focus.set("lists.mode", value)
        }
    }

    Section {
        icon: "apps"
        title: root.whitelist ? Translation.tr("Allowed apps") : Translation.tr("Blocked apps")

        ChipList {
            items: root.apps
            icon: "apps"
            // An empty whitelist would close every window, so it blocks nothing instead.
            emptyText: root.whitelist ? Translation.tr("No apps yet: none are blocked") : Translation.tr("No apps yet")
            onRemoved: value => Focus.removeListItem("apps", value)
        }
        AddField {
            Layout.margins: 6
            placeholder: Translation.tr("Window class or process name, e.g. steam")
            onAdded: text => Focus.addListItem("apps", text)
        }
    }

    Section {
        icon: "language"
        title: root.whitelist ? Translation.tr("Allowed sites") : Translation.tr("Blocked sites")

        ChipList {
            items: root.sites
            icon: "public"
            emptyText: Translation.tr("No sites yet")
            onRemoved: value => Focus.removeListItem("sites", value)
        }
        // /etc/hosts can only send listed sites away, not let only a few through.
        StyledText {
            Layout.fillWidth: true
            Layout.leftMargin: 14
            Layout.rightMargin: 14
            wrapMode: Text.WordWrap
            text: root.whitelist ? Translation.tr("Sites can only be blocked by a blacklist: in whitelist mode they're not restricted.")
                                 : Translation.tr("Blocked through /etc/hosts (asks for your password when a session starts) and by closing browser tabs that open them, for browsers with their own DNS.")
            font.pixelSize: Appearance.font.size.labelMedium
            color: Colors.m3onSurfaceVariant
        }
        AddField {
            Layout.margins: 6
            placeholder: Translation.tr("Domain, e.g. youtube.com")
            onAdded: text => Focus.addListItem("sites", text)
        }
    }
}
