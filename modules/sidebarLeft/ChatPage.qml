import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.common
import qs.common.widgets
import qs.services
import qs.modules.ai

// Claude chat (same conversation as the Super+Y palette): model picker,
// token / cost usage, saved chats, Markdown answers with code blocks.
// Enter sends, Shift+Enter adds a line, Esc stops an answer.
ColumnLayout {
    id: root

    property bool showHistory: false

    function focusInput() {
        input.forceActiveFocus();
    }

    spacing: 10

    RowLayout {
        Layout.fillWidth: true
        spacing: 6

        SegmentedButton {
            model: Claude.models.map(m => m.name)
            currentIndex: Math.max(0, Claude.models.findIndex(m => m.id === Claude.model))
            enabled: !Claude.busy
            onSelected: index => Claude.model = Claude.models[index].id
        }
        Item { Layout.fillWidth: true }
        IconButton {
            implicitWidth: 36
            implicitHeight: 36
            icon: "history"
            filled: root.showHistory
            onClicked: root.showHistory = !root.showHistory
        }
        IconButton {
            implicitWidth: 36
            implicitHeight: 36
            icon: "edit_square"
            enabled: !Claude.busy
            onClicked: {
                Claude.reset();
                root.showHistory = false;
                root.focusInput();
            }
        }
    }

    StyledText {
        Layout.fillWidth: true
        visible: Claude.inputTokens + Claude.outputTokens > 0 && !root.showHistory
        text: Translation.tr("%1 in · %2 out").arg(Claude.formatTokens(Claude.inputTokens)).arg(Claude.formatTokens(Claude.outputTokens)) + (Claude.costUsd > 0 ? " · $" + Claude.costUsd.toFixed(3) : "")
        font.pixelSize: Appearance.font.size.labelSmall
        color: Colors.m3outline
    }

    // --- Saved chats ---
    StyledFlickable {
        Layout.fillWidth: true
        Layout.fillHeight: true
        visible: root.showHistory
        contentHeight: historyColumn.implicitHeight

        ColumnLayout {
            id: historyColumn
            width: parent.width
            spacing: 2

            StyledText {
                visible: Claude.chats.length === 0
                Layout.alignment: Qt.AlignHCenter
                Layout.topMargin: 30
                text: Translation.tr("No saved chats yet")
                color: Colors.m3onSurfaceVariant
            }

            Repeater {
                model: Claude.chats

                ListRow {
                    required property var modelData
                    Layout.fillWidth: true
                    icon: "chat"
                    title: modelData.title
                    subtitle: `${Notifications.relativeTime(modelData.updated)} · ${Translation.trn("%1 message", "%1 messages", Math.ceil(modelData.messages.length / 2))}${modelData.model ? " · " + modelData.model : ""}`
                    clickable: true
                    color: modelData.id === Claude.chatId ? Colors.m3secondaryContainer : "transparent"
                    onClicked: {
                        Claude.open(modelData.id);
                        root.showHistory = false;
                    }

                    IconButton {
                        implicitWidth: 32
                        implicitHeight: 32
                        icon: "delete"
                        onClicked: Claude.remove(modelData.id)
                    }
                }
            }
        }
    }

    // --- Conversation ---
    ListView {
        id: list
        Layout.fillWidth: true
        Layout.fillHeight: true
        visible: !root.showHistory && Claude.messages.count > 0
        clip: true
        spacing: 10
        model: Claude.messages
        boundsBehavior: Flickable.StopAtBounds
        onCountChanged: Qt.callLater(positionViewAtEnd)
        onContentHeightChanged: if (Claude.busy || atYEnd) Qt.callLater(positionViewAtEnd)

        delegate: MessageBubble {
            width: list.width
        }
    }

    // Empty state with a few starters
    ColumnLayout {
        Layout.fillWidth: true
        Layout.fillHeight: true
        visible: !root.showHistory && Claude.messages.count === 0
        spacing: 12

        Item { Layout.fillHeight: true }
        MaterialIcon {
            Layout.alignment: Qt.AlignHCenter
            icon: "auto_awesome"
            fill: 1
            iconSize: 48
            color: Colors.m3primary
        }
        StyledText {
            Layout.alignment: Qt.AlignHCenter
            text: Translation.tr("Ask Claude anything")
            font.pixelSize: Appearance.font.size.titleMedium
        }
        Flow {
            Layout.fillWidth: true
            Layout.leftMargin: 12
            Layout.rightMargin: 12
            spacing: 6

            Repeater {
                model: [Translation.tr("Explain a Linux command"), Translation.tr("Write a bash one-liner"), Translation.tr("Summarize text from my clipboard"), Translation.tr("Translate and fix grammar")]

                Chip {
                    required property string modelData
                    text: modelData
                    onClicked: {
                        if (modelData.includes("clipboard"))
                            Claude.send(`Summarize this:\n\n${Quickshell.clipboardText}`);
                        else {
                            input.text = modelData + ": ";
                            root.focusInput();
                            input.cursorPosition = input.length;
                        }
                    }
                }
            }
        }
        Item { Layout.fillHeight: true }
    }

    // --- Input ---
    Rectangle {
        Layout.fillWidth: true
        implicitHeight: Math.min(160, input.implicitHeight + 24)
        radius: 26
        color: Colors.m3surfaceContainerHighest

        Flickable {
            id: inputFlick
            anchors.fill: parent
            anchors.leftMargin: 18
            anchors.rightMargin: 54
            anchors.topMargin: 12
            anchors.bottomMargin: 12
            contentHeight: input.implicitHeight
            clip: true
            boundsBehavior: Flickable.StopAtBounds

            TextEdit {
                id: input
                width: inputFlick.width
                wrapMode: TextEdit.Wrap
                font.family: Appearance.font.main
                font.pixelSize: Appearance.font.size.bodyMedium
                color: Colors.m3onSurface
                selectionColor: Colors.m3primary
                selectedTextColor: Colors.m3onPrimary
                onCursorRectangleChanged: {
                    if (cursorRectangle.y + cursorRectangle.height > inputFlick.contentY + inputFlick.height)
                        inputFlick.contentY = cursorRectangle.y + cursorRectangle.height - inputFlick.height;
                }

                function submit() {
                    if (Claude.busy || text.trim() === "")
                        return;
                    Claude.send(text);
                    text = "";
                    root.showHistory = false;
                }

                Keys.onPressed: event => {
                    if ((event.key === Qt.Key_Return || event.key === Qt.Key_Enter) && !(event.modifiers & Qt.ShiftModifier)) {
                        submit();
                        event.accepted = true;
                    } else if (event.key === Qt.Key_Escape && Claude.busy) {
                        Claude.cancel();
                        event.accepted = true;
                    }
                }

                StyledText {
                    visible: input.text === ""
                    text: Claude.messages.count > 0 ? Translation.tr("Ask a follow-up…") : Translation.tr("Message Claude…")
                    color: Colors.m3outline
                }
            }
        }

        IconButton {
            anchors.right: parent.right
            anchors.rightMargin: 8
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 8
            filled: true
            icon: Claude.busy ? "stop" : "arrow_upward"
            enabled: Claude.busy || input.text.trim() !== ""
            onClicked: Claude.busy ? Claude.cancel() : input.submit()
        }
    }
}
