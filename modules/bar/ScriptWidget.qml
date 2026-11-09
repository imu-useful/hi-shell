import QtQuick
import Quickshell
import qs.common
import qs.common.widgets

// A bar widget made of a command, no QML: "script#name" in a bar list, with its options in Config bar.instances:
//   "script#gpu": { "command": "nvidia-smi --query-gpu=temperature.gpu --format=csv,noheader", "interval": 5,
//                   "icon": "device_thermostat", "template": "{}°", "click": "kitty -e nvtop" }
// command   run through `sh -c` every `interval` seconds (default 5; 0 = once)
// template  the text, {} is the first line the command printed (default "{}")
// icon      a Material Symbols name (optional)
// json      true: the output is {"text": "...", "icon": "...", "color": "primary|secondary|tertiary|error|#rrggbb"}
// click / rightClick / middleClick   commands run on a click
// scroll up / down: "scrollUp" / "scrollDown" commands
// hideWhenEmpty  hide while the command prints nothing (default true)
BarWidget {
    id: root

    readonly property string command: instance.command ?? ""
    readonly property bool asJson: instance.json === true
    readonly property string template: instance.template ?? "{}"
    readonly property var parsed: {
        if (!asJson)
            return { text: poll.output.split("\n")[0] ?? "" };
        try {
            const v = JSON.parse(poll.output.split("\n")[0] ?? "");
            return v !== null && typeof v === "object" ? v : { text: "" };
        } catch (e) {
            return { text: "" };
        }
    }
    readonly property string rawText: String(parsed.text ?? "")
    readonly property string icon: parsed.icon ?? instance.icon ?? ""
    readonly property color tint: {
        const c = parsed.color ?? instance.color ?? "";
        return c === "primary" ? Colors.m3primary : c === "secondary" ? Colors.m3secondary : c === "tertiary" ? Colors.m3tertiary
            : c === "error" ? Colors.m3error : /^#[0-9a-fA-F]{6,8}$/.test(c) ? c : Colors.m3onSurface;
    }
    readonly property string text: root.rawText === "" ? "" : root.template.split("{}").join(root.rawText)

    shown: command !== "" && (instance.hideWhenEmpty === false || poll.ran && (text !== "" || icon !== ""))
    clickable: (instance.click ?? instance.rightClick ?? instance.middleClick ?? "") !== ""
    scrollable: (instance.scrollUp ?? instance.scrollDown ?? "") !== ""
    padding: 10
    contentWidth: row.implicitWidth
    contentHeight: row.implicitHeight

    function runCommand(cmd) {
        if (cmd)
            Quickshell.execDetached(["sh", "-c", cmd]);
    }
    onClicked: mouse => {
        runCommand(mouse.button === Qt.RightButton ? instance.rightClick : mouse.button === Qt.MiddleButton ? instance.middleClick : instance.click);
        poll.run();
    }
    onScrolled: steps => runCommand(steps > 0 ? instance.scrollUp : instance.scrollDown)

    Poll {
        id: poll
        command: root.command
        interval: root.instance.interval ?? 5
    }

    Grid {
        id: row
        anchors.centerIn: parent
        spacing: 5
        columns: root.vertical ? 1 : 2
        horizontalItemAlignment: Grid.AlignHCenter
        verticalItemAlignment: Grid.AlignVCenter

        MaterialIcon {
            visible: root.icon !== ""
            icon: root.icon
            iconSize: 16
            color: root.tint
        }
        StyledText {
            visible: root.text !== ""
            text: root.text
            color: root.tint
            font.pixelSize: Appearance.font.size.normal
        }
    }
}
