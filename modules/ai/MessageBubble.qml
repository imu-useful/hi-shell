import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.common
import qs.common.widgets

// A single chat message: user prompt (right-aligned pill), Claude's answer
// (Markdown with code blocks in their own cards, each with a copy button), or an error card.
Item {
    id: root

    required property string role
    required property string text
    required property bool done

    readonly property bool isUser: role === "user"
    readonly property bool isError: role === "error"
    readonly property bool thinking: role === "assistant" && !done && text === ""
    readonly property color textColor: isUser ? Colors.m3onPrimaryContainer : isError ? Colors.m3onErrorContainer : Colors.m3onSurface

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

        anchors.right: root.isUser ? parent.right : undefined
        width: root.isUser ? Math.min(userMetrics.advanceWidth + 34, root.width * 0.8) : root.width
        height: content.implicitHeight + 24
        radius: 20
        color: root.isUser ? Colors.m3primaryContainer : root.isError ? Colors.m3errorContainer : Colors.m3surfaceContainerHigh

        TextMetrics {
            id: userMetrics
            font.family: Appearance.font.main
            font.pixelSize: 14
            text: root.isUser ? root.text : ""
        }

        ColumnLayout {
            id: content
            anchors.fill: parent
            anchors.margins: 12
            anchors.leftMargin: 16
            anchors.rightMargin: 16
            spacing: 8

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
                            radius: Appearance.rounding.medium
                            color: Colors.m3surfaceContainerLow
                            border.width: 1
                            border.color: Qt.alpha(Colors.m3outlineVariant, 0.6)

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
