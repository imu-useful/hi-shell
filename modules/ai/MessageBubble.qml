import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.common
import qs.common.widgets

// A single chat message, drawn as a block of a terminal log: a bar down the left side and a header line
// ("❯ YOU", "◆ AI", "✕ ERROR"), then the prompt, the answer (Markdown with code blocks in their own
// outlined cards, each with a copy button) or the error.
Item {
    id: root

    required property string role
    required property string text
    required property bool done

    readonly property bool isUser: role === "user"
    readonly property bool isError: role === "error"
    readonly property bool thinking: role === "assistant" && !done && text === ""
    readonly property color textColor: isError ? Colors.m3error : Colors.m3onSurface
    readonly property color accent: isUser ? Colors.m3primary : isError ? Colors.m3error : Colors.m3tertiary

    // Split into prose and ``` fenced code; a fence still streaming in runs to the end.
    readonly property var segments: {
        if (isUser || isError)
            return [{ code: false, text: text }];
        const out = [];
        const re = /```([^\n`]*)\n?([\s\S]*?)(?:```|$)/g;
        let last = 0, m;
        while ((m = re.exec(text)) !== null) {
            if (m[0].length === 0)
                break;
            if (m.index > last)
                out.push({ code: false, text: text.slice(last, m.index) });
            out.push({ code: true, lang: m[1].trim(), text: m[2].replace(/\n$/, "") });
            last = re.lastIndex;
        }
        if (last < text.length)
            out.push({ code: false, text: text.slice(last) });
        return out.filter(s => s.code || s.text.trim() !== "");
    }

    implicitHeight: bubble.height

    Rectangle {
        id: bubble

        width: root.width
        height: content.implicitHeight + 20
        radius: Appearance.rounding.small
        color: root.isUser ? Qt.alpha(Colors.m3primary, 0.08) : root.isError ? Qt.alpha(Colors.m3error, 0.1) : "transparent"

        Rectangle {
            width: 2
            height: parent.height
            color: root.accent
            opacity: root.isUser || root.isError ? 1 : 0.6
        }

        ColumnLayout {
            id: content
            anchors.fill: parent
            anchors.margins: 10
            anchors.leftMargin: 14
            anchors.rightMargin: 12
            spacing: 6

            MonoLabel {
                text: root.isUser ? "❯ " + Translation.tr("You") : root.isError ? "✕ " + Translation.tr("Error") : "◆ AI"
                color: root.accent
            }

            RowLayout {
                visible: root.thinking
                spacing: 10

                Spinner {
                    implicitWidth: 20
                    implicitHeight: 20
                    color: Colors.m3primary
                }
                StyledText {
                    text: Translation.tr("Claude is thinking…")
                    font.pixelSize: Appearance.font.size.normal
                    color: Colors.m3onSurfaceVariant
                }
            }

            Repeater {
                // By count, so streaming text updates existing items instead of rebuilding them.
                model: root.thinking ? 0 : root.segments.length

                Loader {
                    required property int index
                    readonly property var modelData: root.segments[index] ?? { code: false, text: "" }
                    Layout.fillWidth: true
                    sourceComponent: modelData.code ? codeBlock : prose

                    Component {
                        id: prose
                        TextEdit {
                            text: modelData.text.trim()
                            textFormat: root.isUser ? TextEdit.PlainText : TextEdit.MarkdownText
                            wrapMode: TextEdit.Wrap
                            readOnly: true
                            selectByMouse: true
                            font.family: Appearance.font.main
                            font.pixelSize: 14
                            color: root.textColor
                            selectionColor: Colors.m3primary
                            selectedTextColor: Colors.m3onPrimary
                            onLinkActivated: link => Qt.openUrlExternally(link)
                        }
                    }

                    Component {
                        id: codeBlock
                        Rectangle {
                            implicitHeight: codeColumn.implicitHeight
                            radius: Appearance.rounding.small
                            color: Colors.m3surfaceContainerLowest
                            border.width: 1
                            border.color: Colors.m3outlineVariant

                            ColumnLayout {
                                id: codeColumn
                                width: parent.width
                                spacing: 0

                                RowLayout {
                                    Layout.fillWidth: true
                                    Layout.leftMargin: 12
                                    Layout.rightMargin: 4
                                    Layout.topMargin: 2

                                    StyledText {
                                        Layout.fillWidth: true
                                        text: modelData.lang || "code"
                                        font.family: Appearance.font.mono
                                        font.pixelSize: Appearance.font.size.labelSmall
                                        color: Colors.m3onSurfaceVariant
                                    }
                                    IconButton {
                                        id: copy
                                        property bool copied: false
                                        implicitWidth: 30
                                        implicitHeight: 30
                                        icon: copied ? "check" : "content_copy"
                                        onClicked: {
                                            Quickshell.clipboardText = modelData.text;
                                            copied = true;
                                            copiedTimer.restart();
                                        }
                                        Timer {
                                            id: copiedTimer
                                            interval: 1500
                                            onTriggered: copy.copied = false
                                        }
                                    }
                                }

                                TextEdit {
                                    Layout.fillWidth: true
                                    Layout.margins: 12
                                    Layout.topMargin: 0
                                    text: modelData.text
                                    textFormat: TextEdit.PlainText
                                    wrapMode: TextEdit.WrapAnywhere
                                    readOnly: true
                                    selectByMouse: true
                                    font.family: Appearance.font.mono
                                    font.pixelSize: 13
                                    color: Colors.m3onSurface
                                    selectionColor: Colors.m3primary
                                    selectedTextColor: Colors.m3onPrimary
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
