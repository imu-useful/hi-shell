import QtQuick
import QtQuick.Layouts
import qs.common
import qs.common.widgets
import qs.services
import "../../common/RuleForm.js" as Form

// Edits one rule (Settings > Rules) with fields: a name, conditions joined by "all" or "any",
// the actions to run and the ones for when it ends. A rule the form can't show (groups inside
// groups and the like) opens as JSON, and any rule can be switched to JSON.
// `rule` is the rule as it is saved, or a new one ({ id: "" }). Emits closed() after saving or cancelling.
ColumnLayout {
    id: root

    required property var rule
    readonly property bool isNew: rule.id === ""
    signal closed

    // The form being edited; replaced as a whole on every change.
    property var form: Form.toForm(rule) ?? (isNew ? Form.blank("") : null)
    property bool asJson: form === null
    property string problem: ""
    property bool addingCond: false
    property string addingAction: ""

    function edit(fields) {
        form = Object.assign({}, form, fields);
        problem = "";
    }
    function replaced(list, index, item) {
        return list.map((x, i) => i === index ? item : x);
    }
    function without(list, index) {
        return list.filter((x, i) => i !== index);
    }

    function save() {
        let rule;
        if (asJson) {
            try {
                rule = JSON.parse(json.text);
            } catch (e) {
                problem = e.message;
                return;
            }
        } else {
            if (form.conds.length === 0) {
                problem = Translation.tr("Add a condition: when should the rule work?");
                return;
            }
            if (form.then.length === 0 && form.else.length === 0) {
                problem = Translation.tr("Add an action: what should the rule do?");
                return;
            }
            const taken = Rules.plainRules().map(r => r.id);
            const id = isNew ? Form.idFor(form.name, taken) : form.id;
            rule = Form.fromForm(Object.assign({}, form, { id, name: form.name.trim() || Form.describe(Form.fromForm(form).when, s => Translation.tr(s)) }));
        }
        problem = Rules.putRule(rule);
        if (problem === "")
            closed();
    }

    function toJson() {
        const plain = form ? Form.fromForm(Object.assign({}, form, { id: form.id || Form.idFor(form.name, Rules.plainRules().map(r => r.id)) })) : rule;
        json.text = JSON.stringify(plain, null, 2);
        asJson = true;
        problem = "";
    }
    function toFields() {
        try {
            const back = Form.toForm(JSON.parse(json.text));
            if (back === null) {
                problem = Translation.tr("This rule has groups inside groups or other things the fields can't show; keep editing it as JSON.");
                return;
            }
            form = back;
            asJson = false;
            problem = "";
        } catch (e) {
            problem = e.message;
        }
    }

    Layout.fillWidth: true
    spacing: 10

    // --- Fields ---
    ColumnLayout {
        visible: !root.asJson
        Layout.fillWidth: true
        spacing: 10

        RuleText {
            Layout.fillWidth: true
            value: root.form?.name ?? ""
            placeholder: Translation.tr("Name (optional): what the rule is for")
            onEdited: text => root.edit({ name: text })
        }

        // When
        RowLayout {
            Layout.fillWidth: true
            spacing: 8
            StyledText {
                Layout.fillWidth: true
                text: Translation.tr("When")
                font.pixelSize: Appearance.font.size.titleMedium
                color: Colors.m3primary
            }
            SegmentedButton {
                visible: (root.form?.conds.length ?? 0) > 1
                model: [Translation.tr("All are true"), Translation.tr("Any is true")]
                currentIndex: root.form?.match === "any" ? 1 : 0
                onSelected: index => root.edit({ match: index === 1 ? "any" : "all" })
            }
        }
        Repeater {
            model: root.form?.conds ?? []
            RuleCondRow {
                required property var modelData
                required property int index
                cond: modelData
                onChanged: cond => root.edit({ conds: root.replaced(root.form.conds, index, cond) })
                onRemoved: root.edit({ conds: root.without(root.form.conds, index) })
            }
        }
        Chip {
            icon: root.addingCond ? "expand_less" : "add"
            text: Translation.tr("Add a condition")
            selected: root.addingCond
            onClicked: root.addingCond = !root.addingCond
        }
        Flow {
            visible: root.addingCond
            Layout.fillWidth: true
            spacing: 6
            Repeater {
                model: Form.condTypes
                Chip {
                    required property var modelData
                    icon: modelData.icon
                    text: Translation.tr(modelData.label)
                    onClicked: {
                        root.edit({ conds: [...root.form.conds, Form.newCond(modelData.id)] });
                        root.addingCond = false;
                    }
                }
            }
        }

        // Then, and when it ends
        Repeater {
            model: [
                { part: "then", title: Translation.tr("Then"), hint: "" },
                { part: "else", title: Translation.tr("When it ends"), hint: Translation.tr("Options changed above go back by themselves; add here what else to do") }
            ]
            ColumnLayout {
                id: part
                required property var modelData
                readonly property var list: root.form?.[modelData.part] ?? []
                Layout.fillWidth: true
                Layout.topMargin: 6
                spacing: 8

                StyledText {
                    text: part.modelData.title
                    font.pixelSize: Appearance.font.size.titleMedium
                    color: Colors.m3primary
                }
                StyledText {
                    visible: part.modelData.hint !== ""
                    Layout.fillWidth: true
                    wrapMode: Text.WordWrap
                    text: part.modelData.hint
                    font.pixelSize: Appearance.font.size.labelMedium
                    color: Colors.m3onSurfaceVariant
                }
                Repeater {
                    model: part.list
                    RuleActionRow {
                        required property var modelData
                        required property int index
                        action: modelData
                        onChanged: action => root.edit({ [part.modelData.part]: root.replaced(part.list, index, action) })
                        onRemoved: root.edit({ [part.modelData.part]: root.without(part.list, index) })
                    }
                }
                Chip {
                    icon: root.addingAction === part.modelData.part ? "expand_less" : "add"
                    text: Translation.tr("Add an action")
                    selected: root.addingAction === part.modelData.part
                    onClicked: root.addingAction = root.addingAction === part.modelData.part ? "" : part.modelData.part
                }
                Flow {
                    visible: root.addingAction === part.modelData.part
                    Layout.fillWidth: true
                    spacing: 6
                    Repeater {
                        model: Form.actionTypes
                        Chip {
                            required property var modelData
                            icon: modelData.icon
                            text: Translation.tr(modelData.label)
                            onClicked: {
                                root.edit({ [part.modelData.part]: [...part.list, Form.newAction(modelData.id)] });
                                root.addingAction = "";
                            }
                        }
                    }
                }
            }
        }
    }

    // --- JSON ---
    Rectangle {
        visible: root.asJson
        Layout.fillWidth: true
        implicitHeight: Math.min(360, json.contentHeight + 24)
        radius: Appearance.rounding.medium
        color: Colors.m3surfaceContainerHighest

        Flickable {
            anchors.fill: parent
            anchors.margins: 12
            contentHeight: json.contentHeight
            clip: true
            TextEdit {
                id: json
                width: parent.width
                text: root.form === null ? JSON.stringify(root.rule, null, 2) : ""
                font.family: Appearance.font.mono
                font.pixelSize: Appearance.font.size.labelMedium
                color: Colors.m3onSurface
                wrapMode: TextEdit.WrapAnywhere
                selectByMouse: true
            }
        }
    }

    StyledText {
        visible: root.problem !== ""
        Layout.fillWidth: true
        wrapMode: Text.WordWrap
        text: root.problem
        color: Colors.m3error
        font.pixelSize: Appearance.font.size.labelMedium
    }

    RowLayout {
        Layout.fillWidth: true
        spacing: 8
        M3Button {
            icon: "check"
            text: Translation.tr("Save")
            onClicked: root.save()
        }
        M3Button {
            tonal: true
            text: Translation.tr("Cancel")
            onClicked: root.closed()
        }
        Item { Layout.fillWidth: true }
        M3Button {
            tonal: true
            icon: root.asJson ? "tune" : "data_object"
            text: root.asJson ? Translation.tr("Fields") : "JSON"
            onClicked: root.asJson ? root.toFields() : root.toJson()
        }
    }
}
