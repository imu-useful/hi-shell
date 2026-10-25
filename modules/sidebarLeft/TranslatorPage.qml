import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.common
import qs.common.widgets

// Translator via translate-shell (`trans`): source language is detected,
// target is picked from quick chips (Config translator.languages).
ColumnLayout {
    id: root

    readonly property var options: Config.options.translator
    property string result: ""
    property string error: ""

    function translate() {
        const text = source.text.trim();
        if (text === "") {
            result = "";
            return;
        }
        proc.running = false;
        // "--" so text starting with "-" isn't taken as an option.
        proc.command = ["trans", "-b", "-no-ansi", "-no-warn", `:${options.target}`, "--", text];
        proc.running = true;
    }

    function focusInput() {
        source.forceActiveFocus();
    }

    spacing: 10

    Flow {
        Layout.fillWidth: true
        spacing: 6

        Repeater {
            model: root.options.languages

            Chip {
                required property string modelData
                text: modelData.toUpperCase()
                selected: modelData === root.options.target
                onClicked: {
                    root.options.target = modelData;
                    root.translate();
                }
            }
        }
    }

    component TextCard: Rectangle {
        property alias edit: field
        property string placeholder
        default property alias actions: actionRow.data
        Layout.fillWidth: true
        Layout.fillHeight: true
        radius: Appearance.rounding.extraLarge
        color: Colors.m3surfaceContainer

        StyledFlickable {
            id: flick
            anchors.fill: parent
            anchors.margins: 16
            anchors.bottomMargin: 52
            contentHeight: field.implicitHeight

            TextEdit {
                id: field
                width: flick.width
                wrapMode: TextEdit.Wrap
                font.family: Appearance.font.main
                font.pixelSize: Appearance.font.size.bodyLarge
                color: Colors.m3onSurface
                selectionColor: Colors.m3primary
                selectedTextColor: Colors.m3onPrimary
                selectByMouse: true

                StyledText {
                    visible: field.text === ""
                    text: placeholder
                    font.pixelSize: Appearance.font.size.bodyLarge
                    color: Colors.m3outline
                }
            }
        }

        RowLayout {
            id: actionRow
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.margins: 8
            spacing: 2
        }
    }

    TextCard {
        id: sourceCard
        placeholder: "Type or paste text"

        IconButton {
            icon: "content_paste"
            onClicked: sourceCard.edit.text = Quickshell.clipboardText
        }
        IconButton {
            icon: "close"
            visible: sourceCard.edit.text !== ""
            onClicked: sourceCard.edit.text = ""
        }
    }

    Item {
        Layout.fillWidth: true
        implicitHeight: 40

        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width
            height: 1
            color: Colors.m3outlineVariant
        }
        IconButton {
            anchors.centerIn: parent
            filled: true
            icon: "swap_vert"
            tooltip: "Translate the result back"
            onClicked: {
                if (root.result !== "")
                    sourceCard.edit.text = root.result;
            }
        }
        Spinner {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            visible: proc.running
            implicitWidth: 20
            implicitHeight: 20
            color: Colors.m3primary
        }
    }

    TextCard {
        id: resultCard
        placeholder: root.error || "Translation"
        edit.readOnly: true
        edit.text: root.result

        IconButton {
            icon: "content_copy"
            visible: root.result !== ""
            onClicked: Quickshell.clipboardText = root.result
        }
    }

    readonly property TextEdit source: sourceCard.edit
    Connections {
        target: sourceCard.edit
        function onTextChanged() {
            debounce.restart();
        }
    }
    Timer {
        id: debounce
        interval: 600
        onTriggered: root.translate()
    }

    Process {
        id: proc
        stdout: StdioCollector {
            onStreamFinished: {
                root.result = text.trim();
                root.error = "";
            }
        }
        onExited: code => {
            if (code === 127)
                root.error = "translate-shell (trans) is not installed";
            else if (code !== 0)
                root.error = "Translation failed (network?)";
        }
    }
}
