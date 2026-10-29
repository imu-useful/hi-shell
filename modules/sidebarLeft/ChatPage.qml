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
    property bool showModels: false
    property bool showProviders: false
    property string modelFilter: ""

    function focusInput() {
        input.forceActiveFocus();
    }

    function toggleModels() {
        showModels = !showModels;
        showHistory = showProviders = false;
        if (showModels && Claude.modelList.length === 0)
            Claude.loadModels();
    }

    function toggleProviders() {
        showProviders = !showProviders;
        showHistory = showModels = false;
    }

    spacing: 10

    RowLayout {
        Layout.fillWidth: true
        spacing: 6

        // Who answers: Claude, or one of the providers (the list opens below).
        Chip {
            icon: Claude.compat ? Claude.spec.icon : "auto_awesome"
            text: Claude.providerName
            selected: root.showProviders
            enabled: !Claude.busy
            onClicked: root.toggleProviders()
        }
        Item { Layout.fillWidth: true }
        IconButton {
            implicitWidth: 36
            implicitHeight: 36
            icon: "history"
            filled: root.showHistory
            onClicked: {
                root.showHistory = !root.showHistory;
                root.showModels = root.showProviders = false;
            }
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

    // The model: Claude's three, or a chip that opens the provider's list.
    RowLayout {
        Layout.fillWidth: true
        visible: !root.showProviders

        SegmentedButton {
            visible: !Claude.compat
            model: Claude.models.map(m => m.name)
            currentIndex: Math.max(0, Claude.models.findIndex(m => m.id === Claude.model))
            enabled: !Claude.busy
            onSelected: index => Claude.model = Claude.models[index].id
        }
        Chip {
            visible: Claude.compat
            Layout.maximumWidth: root.width - 20
            icon: "expand_more"
            text: Claude.modelName || Translation.tr("Pick a model")
            selected: root.showModels
            enabled: !Claude.busy
            onClicked: root.toggleModels()
        }
        Item { Layout.fillWidth: true }
    }

    StyledText {
        Layout.fillWidth: true
        visible: Claude.inputTokens + Claude.outputTokens > 0 && !root.showHistory && !root.showModels && !root.showProviders
        text: Translation.tr("%1 in · %2 out").arg(Claude.formatTokens(Claude.inputTokens)).arg(Claude.formatTokens(Claude.outputTokens)) + (Claude.costUsd > 0 ? " · $" + Claude.costUsd.toFixed(3) : "")
        font.pixelSize: Appearance.font.size.labelSmall
        color: Colors.m3outline
    }

    // --- Providers ---
    StyledFlickable {
        Layout.fillWidth: true
        Layout.fillHeight: true
        visible: root.showProviders
        contentHeight: providersColumn.implicitHeight

        ColumnLayout {
            id: providersColumn
            width: parent.width
            spacing: 2

            ListRow {
                Layout.fillWidth: true
                icon: Claude.provider === "claude" ? "check" : "auto_awesome"
                title: "Claude"
                subtitle: Translation.tr("Through the claude CLI (Claude Code)")
                clickable: true
                color: Claude.provider === "claude" ? Colors.m3secondaryContainer : "transparent"
                onClicked: {
                    Claude.provider = "claude";
                    root.showProviders = false;
                    root.focusInput();
                }
            }

            Repeater {
                model: Claude.providers

                ListRow {
                    required property var modelData
                    readonly property bool ready: Claude.configured(modelData.id)
                    Layout.fillWidth: true
                    icon: Claude.provider === modelData.id ? "check" : modelData.icon
                    title: modelData.name
                    subtitle: !ready ? (modelData.urlRequired ? Translation.tr("Set the server address in Settings → General") : Translation.tr("Add an API key in Settings → General")) : Translation.tr(modelData.note ?? "")
                    clickable: true
                    color: Claude.provider === modelData.id ? Colors.m3secondaryContainer : "transparent"
                    onClicked: {
                        Claude.provider = modelData.id;
                        root.showProviders = false;
                        // Straight to the model list when none is chosen yet.
                        if (ready && Claude.modelFor(modelData.id) === "")
                            root.toggleModels();
                        else
                            root.focusInput();
                    }
                }
            }
        }
    }

    // --- The provider's models ---
    Rectangle {
        Layout.fillWidth: true
        implicitHeight: 36
        radius: 18
        visible: root.showModels
        color: Colors.m3surfaceContainerHighest

        TextInput {
            id: modelSearch
            anchors.fill: parent
            anchors.leftMargin: 14
            anchors.rightMargin: 14
            verticalAlignment: TextInput.AlignVCenter
            font.family: Appearance.font.main
            font.pixelSize: Appearance.font.size.bodyMedium
            color: Colors.m3onSurface
            clip: true
            selectByMouse: true
            onTextChanged: root.modelFilter = text.trim().toLowerCase()

            StyledText {
                visible: modelSearch.text === ""
                text: Claude.provider === "openrouter" ? Translation.tr("Search free models…") : Translation.tr("Search models…")
                color: Colors.m3outline
            }
        }
    }

    StyledFlickable {
        Layout.fillWidth: true
        Layout.fillHeight: true
        visible: root.showModels
        contentHeight: modelsColumn.implicitHeight

        ColumnLayout {
            id: modelsColumn
            width: parent.width
            spacing: 2

            StyledText {
                visible: Claude.loadingModels || Claude.modelsError !== "" || (Claude.modelList.length > 0 && modelRepeater.count === 0)
                Layout.alignment: Qt.AlignHCenter
                Layout.topMargin: 30
                Layout.fillWidth: true
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.Wrap
                text: Claude.loadingModels ? Translation.tr("Loading models…") : Claude.modelsError !== "" ? Claude.modelsError : Translation.tr("No models match")
                color: Colors.m3onSurfaceVariant
            }

            Repeater {
                id: modelRepeater
                model: Claude.modelList.filter(m => root.modelFilter === "" || m.id.toLowerCase().includes(root.modelFilter) || m.name.toLowerCase().includes(root.modelFilter))

                ListRow {
                    required property var modelData
                    Layout.fillWidth: true
                    icon: modelData.id === Claude.apiModel ? "check" : "smart_toy"
                    title: modelData.name
                    subtitle: modelData.id
                    clickable: true
                    color: modelData.id === Claude.apiModel ? Colors.m3secondaryContainer : "transparent"
                    onClicked: {
                        Claude.setModel(Claude.provider, modelData.id);
                        root.showModels = false;
                        root.focusInput();
                    }
                }
            }
        }
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
        // Kept for a moment after the last message goes, so the messages can erase away.
        property bool erasing: false
        visible: !root.showHistory && !root.showModels && !root.showProviders && (Claude.messages.count > 0 || erasing)
        clip: true
        spacing: 10
        model: Claude.messages
        boundsBehavior: Flickable.StopAtBounds
        remove: EraseTransition {}
        displaced: Transition {
            SpatialAnim { properties: "y" }
        }
        onCountChanged: {
            if (count === 0) {
                erasing = true;
                eraseHold.restart();
            } else {
                Qt.callLater(positionViewAtEnd);
            }
        }
        Timer {
            id: eraseHold
            interval: Appearance.anim.normal + 12 * 45 * Appearance.anim.speed + 100
            onTriggered: list.erasing = false
        }
        onContentHeightChanged: if (Claude.busy || atYEnd) Qt.callLater(positionViewAtEnd)

        delegate: MessageBubble {
            width: list.width
        }
    }

    // Empty state with a few starters
    ColumnLayout {
        Layout.fillWidth: true
        Layout.fillHeight: true
        visible: !root.showHistory && !root.showModels && !root.showProviders && Claude.messages.count === 0 && !list.erasing
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
                    root.showModels = root.showProviders = false;
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
