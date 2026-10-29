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
        title: Translation.tr("AI chat")

        SwitchRow {
            icon: "power_settings_new"
            title: Translation.tr("Enable AI")
            subtitle: Translation.tr("Off removes the AI tab from the left sidebar and the palette (Super+Y)")
            checked: o.ai.enabled
            onToggled: checked => o.ai.enabled = checked
        }

        // Everything about the AI, only while it's on.
        ColumnLayout {
            Layout.fillWidth: true
            visible: o.ai.enabled
            spacing: 0

            ChoiceRow {
                icon: "neurology"
                title: Translation.tr("Model")
                subtitle: Translation.tr("Used by the palette and the sidebar chat")
                value: Claude.model
                options: Claude.models.map(m => ({ value: m.id, text: m.name }))
                onSelected: value => Claude.model = value
            }
            ListRow {
                Layout.fillWidth: true
                icon: "hub"
                title: Translation.tr("Provider")
                subtitle: Translation.tr("Who answers in the chat (also switched in the chat itself); add their keys below")
            }
            Flow {
                Layout.fillWidth: true
                Layout.leftMargin: 16
                Layout.rightMargin: 16
                Layout.bottomMargin: 6
                spacing: 6

                Chip {
                    icon: "auto_awesome"
                    text: "Claude"
                    selected: Claude.provider === "claude"
                    onClicked: Claude.provider = "claude"
                }
                Repeater {
                    model: Claude.providers
                    Chip {
                        required property var modelData
                        icon: modelData.icon
                        text: modelData.name
                        selected: Claude.provider === modelData.id
                        onClicked: Claude.provider = modelData.id
                    }
                }
            }
            Repeater {
                model: Claude.providers.filter(p => p.key || p.id === "custom")
                TextRow {
                    required property var modelData
                    icon: "key"
                    title: Translation.tr("%1 API key").arg(modelData.name)
                    subtitle: modelData.keyUrl ? Translation.tr("Get one at %1; the model is picked in the sidebar chat").arg(modelData.keyUrl) : Translation.tr("Optional")
                    value: Claude.keyFor(modelData.id)
                    secret: true
                    fieldWidth: 300
                    onEdited: text => Claude.setKey(modelData.id, text.trim())
                }
            }
            Repeater {
                model: Claude.providers.filter(p => p.id === "ollama" || p.urlRequired)
                TextRow {
                    required property var modelData
                    icon: "link"
                    title: Translation.tr("%1 server address").arg(modelData.name)
                    subtitle: modelData.urlRequired ? Translation.tr("Ending in /v1, e.g. http://localhost:1234/v1") : Translation.tr("Default %1").arg(modelData.url)
                    value: Config.options.ai.urls[modelData.id] ?? ""
                    placeholder: modelData.url
                    fieldWidth: 300
                    onEdited: text => Claude.setUrl(modelData.id, text.trim())
                }
            }
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
