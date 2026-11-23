import QtQuick
import QtQuick.Layouts
import qs.common
import qs.common.widgets
import qs.services
import "../../common/RulesEngine.js" as Engine
import "../../common/RuleForm.js" as Form

// Rules: "when this is true, do that" (Config rules, services/Rules.qml, docs/RULES.md).
ColumnLayout {
    id: root

    spacing: 24

    readonly property var list: Rules.plainRules()
    // Reading the config (not just Rules.rules) keeps rules that don't parse in the list, with their error.
    readonly property var configRules: Config.options.rules
    readonly property var templateIds: Object.keys(Engine.templates)
    property bool adding: false

    Section {
        icon: "rule"
        title: Translation.tr("Rules")

        SwitchRow {
            icon: "play_circle"
            title: Translation.tr("Rules are on")
            subtitle: Translation.tr("Off stops every rule and puts back what they changed")
            checked: Config.options.rulesEnabled
            onToggled: checked => Config.options.rulesEnabled = checked
        }
        StyledText {
            Layout.fillWidth: true
            Layout.margins: 14
            Layout.bottomMargin: 0
            wrapMode: Text.WordWrap
            text: Translation.tr("A rule runs its actions when its condition turns true, and when it turns false the options it changed go back. Make one with New rule or from a template below, change it with the pencil, or use `hi rules` in a terminal.")
            font.pixelSize: Appearance.font.size.labelMedium
            color: Colors.m3onSurfaceVariant
        }

        Repeater {
            model: root.configRules ? Rules.plainRules() : []

            ColumnLayout {
                id: row
                required property var modelData
                readonly property var bad: Rules.invalid.find(b => b.id === modelData.id) ?? null
                readonly property bool active: Rules.activeIds.includes(modelData.id)
                property bool editing: false
                Layout.fillWidth: true
                spacing: 0

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 4

                    ListRow {
                        Layout.fillWidth: true
                        icon: row.bad ? "error" : row.active ? "play_circle" : "pause_circle"
                        title: row.modelData.name ? Translation.tr(row.modelData.name) : row.modelData.id
                        subtitle: row.bad ? row.bad.error : (row.active ? Translation.tr("Active now") + " · " : "") + Form.describe(row.modelData.when, s => Translation.tr(s))
                    }
                    M3Switch {
                        checked: row.modelData.enabled !== false
                        onToggled: checked => Rules.setEnabled(row.modelData.id, checked)
                    }
                    IconButton {
                        icon: row.editing ? "close" : "edit"
                        onClicked: row.editing = !row.editing
                    }
                    IconButton {
                        icon: "delete"
                        onClicked: Rules.removeRule(row.modelData.id)
                    }
                }

                Loader {
                    active: row.editing
                    visible: active
                    Layout.fillWidth: true
                    Layout.margins: 14
                    sourceComponent: RuleEditor {
                        rule: row.modelData
                        onClosed: row.editing = false
                    }
                }
            }
        }
        StyledText {
            visible: Rules.plainRules().length === 0
            Layout.margins: 14
            text: Translation.tr("No rules yet")
            color: Colors.m3outline
        }
    }

    Section {
        icon: "library_add"
        title: Translation.tr("Add a rule")

        ListRow {
            visible: !root.adding
            Layout.fillWidth: true
            icon: "add_circle"
            title: Translation.tr("New rule")
            subtitle: Translation.tr("Pick the conditions and what to do, no JSON needed")
            clickable: true
            onClicked: root.adding = true
        }
        Loader {
            active: root.adding
            visible: active
            Layout.fillWidth: true
            Layout.margins: 14
            sourceComponent: RuleEditor {
                rule: ({ id: "" })
                onClosed: root.adding = false
            }
        }
        // Described in words, made by the AI chat's model; opens in the editor and is saved from there.
        StyledText {
            Layout.fillWidth: true
            Layout.leftMargin: 14
            Layout.topMargin: 6
            text: Translation.tr("Or describe it and let the AI make it")
            font.pixelSize: Appearance.font.size.labelMedium
            color: Colors.m3onSurfaceVariant
        }
        RowLayout {
            visible: RuleMaker.draft === null
            Layout.fillWidth: true
            Layout.leftMargin: 14
            Layout.rightMargin: 14
            spacing: 8

            RuleText {
                id: aiText
                Layout.fillWidth: true
                placeholder: Translation.tr("Dark mode from 22:00 to 07:00 on weekdays")
                onEdited: text => {
                    value = text;
                    if (text.trim() !== "")
                        RuleMaker.generate(text);
                }
            }
            M3Button {
                icon: "auto_awesome"
                text: RuleMaker.running ? Translation.tr("Thinking…") : Translation.tr("Make")
                enabled: !RuleMaker.running && aiText.value.trim() !== ""
                onClicked: RuleMaker.generate(aiText.value)
            }
        }
        StyledText {
            visible: RuleMaker.error !== "" && !RuleMaker.running
            Layout.fillWidth: true
            Layout.leftMargin: 14
            wrapMode: Text.WordWrap
            text: RuleMaker.error
            color: Colors.m3error
            font.pixelSize: Appearance.font.size.labelMedium
        }
        StyledText {
            visible: RuleMaker.draft !== null
            Layout.fillWidth: true
            Layout.leftMargin: 14
            wrapMode: Text.WordWrap
            text: Translation.tr("Check what the AI made, commands above all, then save it")
            font.pixelSize: Appearance.font.size.labelMedium
            color: Colors.m3onSurfaceVariant
        }
        Loader {
            active: RuleMaker.draft !== null
            visible: active
            Layout.fillWidth: true
            Layout.margins: 14
            sourceComponent: RuleEditor {
                rule: RuleMaker.draft
                onClosed: {
                    RuleMaker.clear();
                    aiText.value = "";
                }
            }
        }

        StyledText {
            Layout.fillWidth: true
            Layout.leftMargin: 14
            Layout.topMargin: 6
            text: Translation.tr("Or start from a template")
            font.pixelSize: Appearance.font.size.labelMedium
            color: Colors.m3onSurfaceVariant
        }

        Flow {
            Layout.fillWidth: true
            Layout.margins: 10
            spacing: 6

            Repeater {
                model: root.templateIds

                Chip {
                    required property string modelData
                    icon: "add"
                    text: Translation.tr(Engine.templates[modelData].name)
                    enabled: !Rules.plainRules().some(r => r.id === modelData)
                    onClicked: Rules.putRule(Object.assign({ id: modelData }, JSON.parse(JSON.stringify(Engine.templates[modelData]))))
                }
            }
        }
    }
}
