import QtQuick
import QtQuick.Layouts
import qs.common
import qs.common.widgets
import "../../common/RuleForm.js" as Form
import "../../common/ConfigSchema.js" as Schema
import "OptionIndex.js" as OptionIndex

// One action in the rule editor. "Change an option" finds the option by name or description and
// edits the value the way the option is typed (a switch, choices, a number or JSON).
// Never changes `action` itself: emits changed(a new action).
ColumnLayout {
    id: root

    required property var action
    signal changed(var action)
    signal removed

    readonly property var info: Form.actionTypes.find(t => t.id === action.kind) ?? { label: action.kind, icon: "help" }
    readonly property bool isSet: action.kind === "set"
    // The option's value now tells what kind of value it takes.
    readonly property var current: isSet ? Config.getPath(action.path) : undefined
    readonly property bool known: isSet && current !== undefined
    readonly property var choices: isSet ? (Schema.rules[action.path]?.enum ?? []) : []
    readonly property string optionText: isSet ? (OptionIndex.options.find(o => o.path === action.path)?.text ?? "") : ""
    property string search: ""
    readonly property var hits: search.length < 2 ? [] : OptionIndex.options.filter(o => o.path.toLowerCase().includes(search) || o.text.toLowerCase().includes(search)).slice(0, 8)
    property bool badValue: false

    function update(fields) {
        root.changed(Object.assign({}, root.action, fields));
    }
    function pickOption(path) {
        const now = Config.getPath(path);
        // Start from the option's current value, so the rule changes something only once it's edited.
        update({ path, value: now === undefined ? root.action.value : JSON.parse(JSON.stringify(now)) });
        root.search = "";
    }

    Layout.fillWidth: true
    spacing: 6

    RowLayout {
        Layout.fillWidth: true
        spacing: 8

        MaterialIcon {
            icon: root.info.icon
            color: Colors.m3primary
        }
        StyledText {
            Layout.fillWidth: true
            text: Translation.tr(root.info.label)
            font.pixelSize: Appearance.font.size.bodyMedium
            elide: Text.ElideRight
        }
        IconButton {
            implicitWidth: 32
            implicitHeight: 32
            icon: "close"
            tooltip: Translation.tr("Remove")
            onClicked: root.removed()
        }
    }

    // --- Change an option ---
    ColumnLayout {
        visible: root.isSet
        Layout.fillWidth: true
        Layout.leftMargin: 32
        spacing: 6

        RowLayout {
            Layout.fillWidth: true
            spacing: 6
            RuleText {
                Layout.fillWidth: true
                mono: true
                value: root.action.path ?? ""
                placeholder: Translation.tr("Find an option: sounds, bar height…")
                onEdited: text => {
                    const t = text.trim();
                    if (t === root.action.path)
                        return;
                    if (Config.getPath(t) !== undefined)
                        root.pickOption(t);
                    else
                        root.search = t.toLowerCase();
                }
            }
        }
        StyledText {
            visible: root.optionText !== "" && root.search === ""
            Layout.fillWidth: true
            wrapMode: Text.WordWrap
            text: root.optionText
            font.pixelSize: Appearance.font.size.labelMedium
            color: Colors.m3onSurfaceVariant
        }
        StyledText {
            visible: root.isSet && !root.known && root.search === ""
            Layout.fillWidth: true
            wrapMode: Text.WordWrap
            text: Translation.tr("No such option. Type a part of its name or description and press Enter to search.")
            font.pixelSize: Appearance.font.size.labelMedium
            color: Colors.m3error
        }
        // Search results
        Repeater {
            model: root.hits
            ListRow {
                required property var modelData
                Layout.fillWidth: true
                icon: "tune"
                title: modelData.path
                subtitle: modelData.text
                clickable: true
                onClicked: root.pickOption(modelData.path)
            }
        }
        StyledText {
            visible: root.search !== "" && root.hits.length === 0
            text: Translation.tr("Nothing found")
            color: Colors.m3outline
        }

        // The value, by the option's type
        RowLayout {
            visible: root.known && root.search === ""
            Layout.fillWidth: true
            spacing: 8

            StyledText {
                text: Translation.tr("Set to")
                color: Colors.m3onSurfaceVariant
            }
            M3Switch {
                visible: typeof root.current === "boolean"
                checked: root.action.value === true
                onToggled: checked => root.update({ value: checked })
            }
            SegmentedButton {
                visible: root.choices.length > 0 && root.choices.length <= 5
                model: root.choices.map(c => String(c))
                currentIndex: Math.max(0, root.choices.indexOf(root.action.value))
                onSelected: index => root.update({ value: root.choices[index] })
            }
            RuleText {
                visible: typeof root.current !== "boolean" && (root.choices.length === 0 || root.choices.length > 5)
                Layout.fillWidth: true
                mono: typeof root.current === "object"
                value: Form.valueText(root.action.value)
                border.width: root.badValue ? 2 : 0
                border.color: Colors.m3error
                onEdited: text => {
                    const v = Form.parseValue(text, root.current);
                    root.badValue = v === null;
                    if (v !== null)
                        root.update({ value: v });
                }
            }
            Item { Layout.fillWidth: typeof root.current === "boolean" || root.choices.length > 0 }
        }
        SwitchRow {
            visible: root.known && root.search === ""
            Layout.leftMargin: -16
            icon: "push_pin"
            title: Translation.tr("Keep it when the rule ends")
            subtitle: Translation.tr("Otherwise the option goes back to what it was")
            checked: root.action.keep === true
            onToggled: checked => root.update({ keep: checked })
        }
    }

    // --- A text: a notification, a shell call or a command ---
    RuleText {
        visible: ["notify", "ipc", "run"].includes(root.action.kind)
        Layout.fillWidth: true
        Layout.leftMargin: 32
        mono: root.action.kind !== "notify"
        value: root.action.text ?? ""
        placeholder: root.action.kind === "notify" ? Translation.tr("The notification's text") : root.action.kind === "ipc" ? "theme setMode dark" : "notify-send hi"
        onEdited: text => root.update({ text: text })
    }
    StyledText {
        visible: root.action.kind === "ipc" || root.action.kind === "run"
        Layout.fillWidth: true
        Layout.leftMargin: 32
        wrapMode: Text.WordWrap
        text: root.action.kind === "ipc" ? Translation.tr("A target and a function, as in `hi ipc` (it lists them). Not undone when the rule ends: add the opposite under “When it ends”.")
                                         : Translation.tr("A shell command. Not undone when the rule ends: add the opposite under “When it ends”.")
        font.pixelSize: Appearance.font.size.labelMedium
        color: Colors.m3onSurfaceVariant
    }

    // --- A preset ---
    Flow {
        visible: root.action.kind === "profile"
        Layout.fillWidth: true
        Layout.leftMargin: 32
        spacing: 6
        RuleText {
            implicitWidth: 180
            value: root.action.profile ?? ""
            placeholder: Translation.tr("preset name, or undo")
            onEdited: text => root.update({ profile: text.trim() })
        }
        RuleText {
            implicitWidth: 220
            mono: true
            value: root.action.only ?? ""
            placeholder: Translation.tr("only these parts: bar,dock")
            onEdited: text => root.update({ only: text.replace(/\s+/g, "") })
        }
    }
}
