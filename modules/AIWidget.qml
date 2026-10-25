import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import Quickshell.Wayland
import qs.common
import qs.common.widgets
import qs.modules.ai

// Claude AI command palette.
// Toggle: Hyprland keybind (hypr/hi-shell.lua) or `qs -c hi-shell ipc call ai toggle`.
Scope {
    id: root

    property bool open: false
    // Unsent prompt; kept here because the window is destroyed while closed.
    property string draft: ""

    function toggle() {
        open = !open;
    }

    function close() {
        open = false;
    }

    ClaudeSession {
        id: session
    }


    IpcHandler {
        target: "ai"

        function toggle(): void {
            root.toggle();
        }
        function open(): void {
            root.open = true;
        }
        function close(): void {
            root.close();
        }
        function ask(prompt: string): void {
            root.open = true;
            session.send(prompt);
        }
        function reset(): void {
            session.reset();
        }
    }

    PanelLoader {
        id: loader
        shown: root.open

        PanelWindow {
            id: window

            screen: Quickshell.screens.find(s => s.name === Hyprland.focusedMonitor?.name) ?? Quickshell.screens[0]

            anchors.top: true
            margins.top: screen ? screen.height * 0.12 : 0
            implicitWidth: 720
            implicitHeight: card.implicitHeight
            color: "transparent"

            exclusionMode: ExclusionMode.Ignore
            WlrLayershell.namespace: "hi-shell-ai"
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.keyboardFocus: root.open ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

            HyprlandFocusGrab {
                windows: [window]
                active: root.open
                onCleared: root.close()
            }

            // The window is created already open, so also focus on creation.
            Component.onCompleted: input.forceActiveFocus()
            Connections {
                target: root
                function onOpenChanged() {
                    if (root.open)
                        input.forceActiveFocus();
                }
            }

            // Esc stops a running request first, then closes the palette.
            Shortcut {
                sequence: "Escape"
                onActivated: session.busy ? session.cancel() : root.close()
            }
            Shortcut {
                sequence: "Ctrl+N"
                onActivated: session.reset()
            }

            Rectangle {
                id: card

                width: parent.width
                implicitHeight: column.implicitHeight + 24
                radius: Appearance.rounding.extraLarge
                color: Appearance.translucent(Colors.m3surfaceContainer)
                border.width: 1
                border.color: Colors.m3outlineVariant

                opacity: loader.revealed ? 1 : 0
                scale: loader.revealed ? 1 : 0.95
                transformOrigin: Item.Top
                Behavior on opacity { EffectAnim {} }
                Behavior on scale { EffectAnim {} }

                ColumnLayout {
                    id: column
                    anchors.fill: parent
                    anchors.margins: 12
                    spacing: 10

                    // Header
                    RowLayout {
                        Layout.fillWidth: true
                        Layout.leftMargin: 8
                        spacing: 10

                        Text {
                            text: "auto_awesome"
                            font.family: Appearance.font.icon
                            font.pixelSize: 22
                            color: Colors.m3primary
                        }

                        Text {
                            Layout.fillWidth: true
                            text: "Claude"
                            font.family: Appearance.font.main
                            font.pixelSize: 16
                            font.weight: Font.Medium
                            color: Colors.m3onSurface
                        }

                        IconButton {
                            icon: "content_copy"
                            visible: session.messages.count > 0
                            enabled: !session.busy
                            onClicked: Quickshell.clipboardText = session.lastAnswer()
                        }

                        IconButton {
                            icon: "add_comment"
                            visible: session.messages.count > 0
                            onClicked: {
                                session.reset();
                                input.forceActiveFocus();
                            }
                        }
                    }

                    // Conversation
                    ListView {
                        id: list

                        readonly property real maxHeight: window.screen ? window.screen.height * 0.55 : 500

                        Layout.fillWidth: true
                        implicitHeight: Math.min(contentHeight, maxHeight)
                        visible: count > 0
                        clip: true
                        spacing: 10
                        model: session.messages
                        boundsBehavior: Flickable.StopAtBounds

                        // Follow the answer while it streams in.
                        onContentHeightChanged: if (session.busy || atYEnd) Qt.callLater(positionViewAtEnd)
                        onCountChanged: Qt.callLater(positionViewAtEnd)

                        delegate: MessageBubble {
                            width: list.width
                        }
                    }

                    Text {
                        Layout.fillWidth: true
                        Layout.margins: 8
                        visible: session.messages.count === 0
                        text: "Ask Claude anything.  Enter to send · Esc to close · Ctrl+N for a new chat"
                        wrapMode: Text.Wrap
                        font.family: Appearance.font.main
                        font.pixelSize: 12
                        color: Colors.m3onSurfaceVariant
                    }

                    // Prompt input
                    Rectangle {
                        Layout.fillWidth: true
                        implicitHeight: 56
                        radius: Appearance.rounding.full
                        color: Colors.m3surfaceContainerHighest

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 20
                            anchors.rightMargin: 8
                            spacing: 12

                            TextInput {
                                id: input
                                Layout.fillWidth: true
                                Component.onCompleted: text = root.draft
                                onTextChanged: root.draft = text
                                font.family: Appearance.font.main
                                font.pixelSize: 16
                                color: Colors.m3onSurface
                                selectionColor: Colors.m3primary
                                selectedTextColor: Colors.m3onPrimary
                                clip: true

                                function submit() {
                                    if (session.busy || text.trim() === "")
                                        return;
                                    session.send(text);
                                    text = "";
                                }

                                Keys.onReturnPressed: submit()
                                Keys.onEnterPressed: submit()

                                Text {
                                    anchors.verticalCenter: parent.verticalCenter
                                    visible: input.text === ""
                                    text: session.messages.count > 0 ? "Ask a follow-up…" : "Ask Claude…"
                                    font: input.font
                                    color: Colors.m3onSurfaceVariant
                                }
                            }

                            // Send / stop
                            IconButton {
                                filled: true
                                icon: session.busy ? "stop" : "arrow_upward"
                                enabled: session.busy || input.text.trim() !== ""
                                onClicked: session.busy ? session.cancel() : input.submit()
                            }
                        }
                    }
                }
            }
        }
    }
}
