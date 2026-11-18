import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.common
import qs.common.widgets
import "../../common/RuleForm.js" as Form

// One condition in the rule editor: its kind, the fields of that kind, "not" and remove.
// Never changes `cond` itself: emits changed(a new cond).
ColumnLayout {
    id: root

    required property var cond
    signal changed(var cond)
    signal removed

    readonly property var info: Form.condTypes.find(t => t.id === cond.type) ?? { label: cond.type, icon: "help" }
    // Monday first, as calendars here show the week
    readonly property var weekOrder: [1, 2, 3, 4, 5, 6, 0]
    readonly property var dayNames: ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]

    function update(fields) {
        root.changed(Object.assign({}, root.cond, fields));
    }
    // A number field's text: a number, null when it's left empty, or `old` when it isn't a number.
    function numberOrNull(text, old) {
        const t = text.trim();
        if (t === "")
            return null;
        const n = Number(t.replace(",", "."));
        return isFinite(n) ? n : old;
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
        Chip {
            icon: root.cond.not ? "block" : ""
            text: Translation.tr("Not")
            selected: root.cond.not
            onClicked: root.update({ not: !root.cond.not })
        }
        IconButton {
            implicitWidth: 32
            implicitHeight: 32
            icon: "close"
            tooltip: Translation.tr("Remove")
            onClicked: root.removed()
        }
    }

    Flow {
        Layout.fillWidth: true
        Layout.leftMargin: 32
        spacing: 6

        // Battery state
        SegmentedButton {
            visible: root.cond.type === "batteryState"
            model: [Translation.tr("On battery"), Translation.tr("Charging"), Translation.tr("Full"), Translation.tr("Plugged in")]
            currentIndex: Math.max(0, ["discharging", "charging", "full", "plugged"].indexOf(root.cond.state))
            onSelected: index => root.update({ state: ["discharging", "charging", "full", "plugged"][index] })
        }

        // Battery level: below and / or above, a field left empty is no limit
        StyledText {
            visible: root.cond.type === "batteryLevel"
            height: 36
            verticalAlignment: Text.AlignVCenter
            text: Translation.tr("below, %")
            color: Colors.m3onSurfaceVariant
        }
        RuleText {
            visible: root.cond.type === "batteryLevel"
            implicitWidth: 70
            value: root.cond.below === null || root.cond.below === undefined ? "" : String(root.cond.below)
            placeholder: "—"
            onEdited: text => root.update({ below: root.numberOrNull(text, root.cond.below) })
        }
        StyledText {
            visible: root.cond.type === "batteryLevel"
            height: 36
            verticalAlignment: Text.AlignVCenter
            text: Translation.tr("above, %")
            color: Colors.m3onSurfaceVariant
        }
        RuleText {
            visible: root.cond.type === "batteryLevel"
            implicitWidth: 70
            value: root.cond.above === null || root.cond.above === undefined ? "" : String(root.cond.above)
            placeholder: "—"
            onEdited: text => root.update({ above: root.numberOrNull(text, root.cond.above) })
        }

        // Time of day
        StyledText {
            visible: root.cond.type === "time"
            height: 36
            verticalAlignment: Text.AlignVCenter
            text: Translation.tr("from")
            color: Colors.m3onSurfaceVariant
        }
        RuleText {
            visible: root.cond.type === "time"
            implicitWidth: 80
            value: root.cond.from ?? ""
            placeholder: "22:00"
            onEdited: text => root.update({ from: text.trim() })
        }
        StyledText {
            visible: root.cond.type === "time"
            height: 36
            verticalAlignment: Text.AlignVCenter
            text: Translation.tr("to")
            color: Colors.m3onSurfaceVariant
        }
        RuleText {
            visible: root.cond.type === "time"
            implicitWidth: 80
            value: root.cond.to ?? ""
            placeholder: "07:00"
            onEdited: text => root.update({ to: text.trim() })
        }

        // Days of the week
        Repeater {
            model: root.cond.type === "weekday" ? root.weekOrder : []
            Chip {
                required property int modelData
                text: Translation.tr(root.dayNames[modelData])
                selected: (root.cond.days ?? []).includes(modelData)
                onClicked: {
                    const days = root.cond.days ?? [];
                    root.update({ days: selected ? days.filter(d => d !== modelData) : [...days, modelData] });
                }
            }
        }

        // Yes / no kinds
        SegmentedButton {
            visible: ["fullscreen", "dark", "playing"].includes(root.cond.type)
            model: root.cond.type === "fullscreen" ? [Translation.tr("A window is fullscreen"), Translation.tr("None is")]
                 : root.cond.type === "dark" ? [Translation.tr("Dark"), Translation.tr("Light")]
                 : [Translation.tr("Playing"), Translation.tr("Not playing")]
            currentIndex: root.cond.on === false ? 1 : 0
            onSelected: index => root.update({ on: index === 0 })
        }

        // Texts: an app's class, a screen's name, a command
        RuleText {
            visible: ["app", "appOpen", "screen", "command"].includes(root.cond.type)
            implicitWidth: root.cond.type === "command" ? Math.min(420, root.width - 40) : 220
            mono: root.cond.type === "command"
            value: root.cond.text ?? ""
            placeholder: root.cond.type === "screen" ? "HDMI-A-1" : root.cond.type === "command" ? "ping -c1 -W1 192.168.1.1" : Translation.tr("window class, e.g. firefox")
            onEdited: text => root.update({ text: text.trim() })
        }
        // The screens connected now, to pick one
        Repeater {
            model: root.cond.type === "screen" ? Quickshell.screens.map(s => s.name) : []
            Chip {
                required property string modelData
                icon: "monitor"
                text: modelData
                selected: root.cond.text === modelData
                onClicked: root.update({ text: modelData })
            }
        }

        // Number of screens
        SegmentedButton {
            visible: root.cond.type === "screenCount"
            model: [Translation.tr("exactly"), Translation.tr("at least"), Translation.tr("at most")]
            currentIndex: Math.max(0, ["is", "atLeast", "atMost"].indexOf(root.cond.op))
            onSelected: index => root.update({ op: ["is", "atLeast", "atMost"][index] })
        }
        NumberField {
            visible: root.cond.type === "screenCount" || root.cond.type === "workspace"
            height: 36
            value: root.cond.n ?? 1
            from: root.cond.type === "workspace" ? -100 : 0
            to: 100
            onCommitted: value => root.update({ n: Math.round(value) })
        }
    }

    StyledText {
        visible: root.cond.type === "command"
        Layout.fillWidth: true
        Layout.leftMargin: 32
        wrapMode: Text.WordWrap
        text: Translation.tr("True while the command exits with 0; it's run every 30 seconds.")
        font.pixelSize: Appearance.font.size.labelMedium
        color: Colors.m3onSurfaceVariant
    }
}
