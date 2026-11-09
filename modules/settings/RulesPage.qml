import QtQuick
import QtQuick.Layouts
import qs.common
import qs.common.widgets
import qs.services
import "../../common/RulesEngine.js" as Engine

// Rules: "when this is true, do that" (Config rules, services/Rules.qml, docs/RULES.md).
ColumnLayout {
    id: root

    spacing: 24

    readonly property var list: Rules.plainRules()
    // Reading the config (not just Rules.rules) keeps rules that don't parse in the list, with their error.
    readonly property var configRules: Config.options.rules
    readonly property var templateIds: Object.keys(Engine.templates)

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
            text: Translation.tr("A rule runs its actions when its condition turns true, and when it turns false the options it changed go back. Start from a template below, change a rule with Edit, or use `hi rules` in a terminal.")
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
                property string problem: ""
                Layout.fillWidth: true
                spacing: 0

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 4

                    ListRow {
                        Layout.fillWidth: true
                        icon: row.bad ? "error" : row.active ? "play_circle" : "pause_circle"
                        title: row.modelData.name || row.modelData.id
                        subtitle: row.bad ? row.bad.error : (row.active ? Translation.tr("Active now") + " · " : "") + Engine.describe(row.modelData.when)
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

                ColumnLayout {
                    visible: row.editing
                    Layout.fillWidth: true
                    Layout.margins: 14
                    spacing: 8

                    Rectangle {
                        Layout.fillWidth: true
                        implicitHeight: Math.min(320, editor.contentHeight + 24)
                        radius: Appearance.rounding.medium
                        color: Colors.m3surfaceContainerHighest

                        Flickable {
                            anchors.fill: parent
                            anchors.margins: 12
                            contentHeight: editor.contentHeight
                            clip: true
                            TextEdit {
                                id: editor
                                width: parent.width
                                text: JSON.stringify(row.modelData, null, 2)
                                font.family: Appearance.font.mono
                                font.pixelSize: Appearance.font.size.labelMedium
                                color: Colors.m3onSurface
                                wrapMode: TextEdit.WrapAnywhere
                                selectByMouse: true
                            }
                        }
                    }
                    StyledText {
                        visible: row.problem !== ""
                        Layout.fillWidth: true
                        wrapMode: Text.WordWrap
                        text: row.problem
                        color: Colors.m3error
                        font.pixelSize: Appearance.font.size.labelMedium
                    }
                    M3Button {
                        icon: "check"
                        text: Translation.tr("Save")
                        onClicked: {
                            try {
                                row.problem = Rules.putRule(JSON.parse(editor.text));
                                if (row.problem === "")
                                    row.editing = false;
                            } catch (e) {
                                row.problem = e.message;
                            }
                        }
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
