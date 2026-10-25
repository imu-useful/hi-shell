import QtQuick
import QtQuick.Layouts
import qs.common
import qs.common.widgets

// A single chat message: user prompt (right-aligned pill), Claude's answer
// (full-width Markdown card), or an error card.
Item {
    id: root

    required property string role
    required property string text
    required property bool done

    readonly property bool isUser: role === "user"
    readonly property bool isError: role === "error"
    readonly property bool thinking: role === "assistant" && !done && text === ""

    implicitHeight: bubble.height

    Rectangle {
        id: bubble

        anchors.right: root.isUser ? parent.right : undefined
        width: root.isUser ? Math.min(body.implicitWidth + 32, root.width * 0.8) : root.width
        height: content.implicitHeight + 24
        radius: 20
        color: root.isUser ? Colors.m3primaryContainer : root.isError ? Colors.m3errorContainer : Colors.m3surfaceContainerHigh

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

                Text {
                    text: "Claude is thinking…"
                    font.family: Appearance.font.main
                    font.pixelSize: Appearance.font.size.normal
                    color: Colors.m3onSurfaceVariant
                }
            }

            TextEdit {
                id: body
                Layout.fillWidth: true
                visible: !root.thinking
                text: root.text
                textFormat: root.isUser ? TextEdit.PlainText : TextEdit.MarkdownText
                wrapMode: TextEdit.Wrap
                readOnly: true
                selectByMouse: true
                font.family: Appearance.font.main
                font.pixelSize: 14
                color: root.isUser ? Colors.m3onPrimaryContainer : root.isError ? Colors.m3onErrorContainer : Colors.m3onSurface
                selectionColor: Colors.m3primary
                selectedTextColor: Colors.m3onPrimary
                onLinkActivated: link => Qt.openUrlExternally(link)
            }
        }
    }
}
