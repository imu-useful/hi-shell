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
        ChoiceRow {
            icon: "hub"
            title: Translation.tr("Provider")
            subtitle: Translation.tr("OpenRouter runs any of its models, the free ones included")
            value: Claude.provider
            options: [{ value: "claude", text: "Claude" }, { value: "openrouter", text: "OpenRouter" }]
            onSelected: value => Claude.provider = value
        }
        TextRow {
            icon: "key"
            title: Translation.tr("OpenRouter API key")
            subtitle: Translation.tr("Free at openrouter.ai/keys; the model is picked in the sidebar chat")
            value: o.ai.openrouterKey
            secret: true
            fieldWidth: 300
            onEdited: text => o.ai.openrouterKey = text.trim()
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
