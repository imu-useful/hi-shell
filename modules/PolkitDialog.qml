import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import Quickshell.Services.Polkit
import qs.common
import qs.common.widgets
import qs.common.shapes

// Polkit authentication agent: the password prompt apps get when they need
// admin rights (pkexec, GUI package managers, disk tools, ...).
Scope {
    id: root

    readonly property var flow: agent.flow

    PolkitAgent {
        id: agent
    }

    PanelLoader {
        id: loader
        shown: agent.isActive && root.flow !== null

        PanelWindow {
            id: window

            screen: Quickshell.screens.find(s => s.name === Hyprland.focusedMonitor?.name) ?? Quickshell.screens[0]
            anchors.top: true
            anchors.bottom: true
            anchors.left: true
            anchors.right: true
            exclusionMode: ExclusionMode.Ignore
            color: "transparent"

            WlrLayershell.namespace: "hi-shell-polkit"
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

            function submit() {
                if (!root.flow || !root.flow.isResponseRequired)
                    return;
                root.flow.submit(password.text);
                password.text = "";
            }
            function cancel() {
                root.flow?.cancelAuthenticationRequest();
            }

            Rectangle {
                anchors.fill: parent
                color: Qt.alpha("black", 0.45)
                opacity: loader.revealed ? 1 : 0
                Behavior on opacity { EffectAnim {} }
            }

            Rectangle {
                id: card

                anchors.centerIn: parent
                width: 440
                implicitHeight: content.implicitHeight + 48
                radius: Appearance.rounding.extraLarge
                color: Colors.m3surfaceContainerHigh

                opacity: loader.revealed ? 1 : 0
                scale: loader.revealed ? 1 : 0.94
                Behavior on opacity { EffectAnim {} }
                Behavior on scale { EffectAnim {} }

                ColumnLayout {
                    id: content
                    anchors.fill: parent
                    anchors.margins: 24
                    spacing: 16

                    Item {
                        Layout.alignment: Qt.AlignHCenter
                        implicitWidth: 64
                        implicitHeight: 64
                        MaterialShape {
                            anchors.fill: parent
                            shape: "cookie9"
                            color: Colors.m3primaryContainer
                        }
                        MaterialIcon {
                            anchors.centerIn: parent
                            icon: "admin_panel_settings"
                            fill: 1
                            iconSize: 32
                            color: Colors.m3onPrimaryContainer
                        }
                    }

                    StyledText {
                        Layout.alignment: Qt.AlignHCenter
                        text: Translation.tr("Authentication required")
                        font.pixelSize: Appearance.font.size.headlineSmall
                    }
                    StyledText {
                        Layout.fillWidth: true
                        text: root.flow?.message || Translation.tr("An application wants to make changes that need administrator rights.")
                        wrapMode: Text.Wrap
                        horizontalAlignment: Text.AlignHCenter
                        color: Colors.m3onSurfaceVariant
                    }
                    StyledText {
                        Layout.fillWidth: true
                        text: root.flow?.actionId ?? ""
                        horizontalAlignment: Text.AlignHCenter
                        font.family: Appearance.font.mono
                        font.pixelSize: Appearance.font.size.labelSmall
                        color: Colors.m3outline
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        implicitHeight: 52
                        radius: Appearance.rounding.medium
                        color: Colors.m3surfaceContainerHighest
                        border.width: 2
                        border.color: root.flow?.supplementaryIsError ? Colors.m3error : password.activeFocus ? Colors.m3primary : Colors.m3outline

                        TextInput {
                            id: password
                            anchors.fill: parent
                            anchors.leftMargin: 16
                            anchors.rightMargin: 16
                            verticalAlignment: TextInput.AlignVCenter
                            echoMode: root.flow?.responseVisible ? TextInput.Normal : TextInput.Password
                            enabled: root.flow?.isResponseRequired ?? false
                            font.family: Appearance.font.main
                            font.pixelSize: Appearance.font.size.bodyLarge
                            color: Colors.m3onSurface
                            focus: true
                            clip: true
                            onAccepted: window.submit()
                            Keys.onEscapePressed: window.cancel()
                            // Polkit asks for the password a moment after the dialog opens
                            // (and again after a wrong one); focus the field then.
                            onEnabledChanged: if (enabled) forceActiveFocus()
                            Component.onCompleted: forceActiveFocus()

                            StyledText {
                                anchors.fill: parent
                                visible: password.text === ""
                                text: (root.flow?.inputPrompt || Translation.tr("Password")).replace(/:\s*$/, "")
                                color: Colors.m3outline
                            }
                        }
                    }

                    StyledText {
                        Layout.fillWidth: true
                        visible: text !== ""
                        text: root.flow?.supplementaryMessage ?? ""
                        wrapMode: Text.Wrap
                        font.pixelSize: Appearance.font.size.labelMedium
                        color: root.flow?.supplementaryIsError ? Colors.m3error : Colors.m3onSurfaceVariant
                    }

                    RowLayout {
                        Layout.alignment: Qt.AlignRight
                        spacing: 8
                        M3Button {
                            tonal: true
                            text: Translation.tr("Cancel")
                            onClicked: window.cancel()
                        }
                        M3Button {
                            text: Translation.tr("Authenticate")
                            enabled: root.flow?.isResponseRequired ?? false
                            onClicked: window.submit()
                        }
                    }
                }
            }
        }
    }
}
