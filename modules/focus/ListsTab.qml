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
        AddField {
            Layout.margins: 6
            placeholder: Translation.tr("Domain, e.g. youtube.com")
            onAdded: text => Focus.addListItem("sites", text)
        }
    }
}
