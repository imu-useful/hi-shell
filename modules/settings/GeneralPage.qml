import QtQuick
import QtQuick.Layouts
import qs.common
import qs.common.widgets
import qs.services

// Language, apps, Claude, translator, clipboard.
ColumnLayout {
    readonly property var o: Config.options
    spacing: 24

    Section {
        icon: "language"
        title: Translation.tr("Language")

        ChoiceRow {
            icon: "translate"
            title: Translation.tr("Interface language")
            subtitle: o.language === "auto" ? Translation.tr("Auto follows $LANG") : ""
            value: o.language
            options: [{ value: "auto", text: Translation.tr("Auto") }, ...Translation.available.map(l => ({ value: l.code, text: l.name }))]
            onSelected: value => o.language = value
        }
    }

    Section {
        icon: "apps"
        title: Translation.tr("Apps")

        TextRow {
            icon: "terminal"
            title: Translation.tr("Terminal")
            subtitle: Translation.tr("For terminal apps and system upgrades")
            value: o.apps.terminal
            onEdited: text => o.apps.terminal = text.trim() || "kitty"
        }
    }

    Section {
        icon: "auto_awesome"
        title: Translation.tr("Claude")

        ChoiceRow {
            icon: "neurology"
            title: Translation.tr("Model")
            subtitle: Translation.tr("Used by the palette and the sidebar chat")
            value: Claude.model
            options: Claude.models.map(m => ({ value: m.id, text: m.name }))
            onSelected: value => Claude.model = value
        }
    }

    Section {
        icon: "translate"
        title: Translation.tr("Translator")

        TextRow {
            icon: "language"
            title: Translation.tr("Languages")
            subtitle: Translation.tr("Quick picks, comma separated codes")
            value: o.translator.languages.join(", ")
            onEdited: text => o.translator.languages = text.split(",").map(l => l.trim().toLowerCase()).filter(l => l)
        }
    }

    Section {
        icon: "content_paste"
        title: Translation.tr("Clipboard")

        SwitchRow {
            icon: "history"
            title: Translation.tr("Keep clipboard history")
            subtitle: Translation.tr("Starts wl-paste --watch cliphist store with the shell")
            checked: o.clipboard.watch
            onToggled: checked => o.clipboard.watch = checked
        }
    }
}
