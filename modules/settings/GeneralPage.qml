import QtQuick
import QtQuick.Layouts
import qs.common
import qs.common.widgets
import qs.services

// Language, apps, Claude, translator, clipboard.
ColumnLayout {
    readonly property var o: Config.options
    spacing: 24

    // The model picked for the generated language (empty: the provider's default).
    property string langModelId: ""

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
        ListRow {
            Layout.fillWidth: true
            icon: "auto_awesome"
            title: Translation.tr("Make a language with AI")
            subtitle: Translation.tr("Type the code (de, fr, pt-BR), and a model: the shell's strings are translated into it, and it appears above")
        }
        TextRow {
            id: langCode
            icon: "tag"
            title: Translation.tr("Language code")
            placeholder: "de"
            fieldWidth: 160
            onEdited: text => langCode.value = text.trim()
        }
        TextRow {
            id: langName
            icon: "translate"
            title: Translation.tr("Name in that language")
            placeholder: Translation.tr("Deutsch (optional)")
            fieldWidth: 160
            onEdited: text => langName.value = text.trim()
        }
        ModelChoice {
            id: langModel
            title: Translation.tr("Model")
            current: langModelId
            fallback: Config.options.ai.provider === "claude" ? "sonnet" : (Config.options.ai.models[Config.options.ai.provider] ?? "")
            onPicked: id => langModelId = id
        }
        ListRow {
            Layout.fillWidth: true
            icon: "play_arrow"
            title: LanguageMaker.running ? LanguageMaker.status : (LanguageMaker.error || LanguageMaker.status || Translation.tr("Ready"))
            subtitle: LanguageMaker.error && !LanguageMaker.running ? Translation.tr("See the shell's log for the details") : ""
            M3Button {
                text: Translation.tr("Generate")
                icon: "auto_awesome"
                enabled: !LanguageMaker.running && /^[a-z]{2,3}(-[A-Za-z]{2,4})?$/.test(langCode.value) && langCode.value !== "en"
                onClicked: LanguageMaker.generate(langCode.value, langName.value, langModel.shown)
            }
        }
        Repeater {
            model: Config.options.customLanguages

            ListRow {
                required property var modelData
                Layout.fillWidth: true
                icon: "translate"
                title: modelData.name
                subtitle: modelData.code
                IconButton {
                    icon: "delete"
                    tooltip: Translation.tr("Delete this language")
                    onClicked: LanguageMaker.remove(modelData.code)
                }
            }
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
