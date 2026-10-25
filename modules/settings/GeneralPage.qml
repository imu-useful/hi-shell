import QtQuick
import QtQuick.Layouts
import qs.common
import qs.common.widgets
import qs.services

// Apps, Claude, translator, clipboard.
ColumnLayout {
    readonly property var o: Config.options
    spacing: 24

    Section {
        icon: "apps"
        title: "Apps"

        TextRow {
            icon: "terminal"
            title: "Terminal"
            subtitle: "For terminal apps and system upgrades"
            value: o.apps.terminal
            onEdited: text => o.apps.terminal = text.trim() || "kitty"
        }
    }

    Section {
        icon: "auto_awesome"
        title: "Claude"

        ChoiceRow {
            icon: "neurology"
            title: "Model"
            subtitle: "Used by the palette and the sidebar chat"
            value: Claude.model
            options: Claude.models.map(m => ({ value: m.id, text: m.name }))
            onSelected: value => Claude.model = value
        }
    }

    Section {
        icon: "translate"
        title: "Translator"

        TextRow {
            icon: "language"
            title: "Languages"
            subtitle: "Quick picks, comma separated codes"
            value: o.translator.languages.join(", ")
            onEdited: text => o.translator.languages = text.split(",").map(l => l.trim().toLowerCase()).filter(l => l)
        }
    }

    Section {
        icon: "content_paste"
        title: "Clipboard"

        SwitchRow {
            icon: "history"
            title: "Keep clipboard history"
            subtitle: "Starts wl-paste --watch cliphist store with the shell"
            checked: o.clipboard.watch
            onToggled: checked => o.clipboard.watch = checked
        }
    }
}
