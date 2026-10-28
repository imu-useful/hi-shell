import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import qs.common
import qs.common.widgets
import qs.services

// "Keep these display settings?" after a new resolution, orientation or scale is tried
// (services/HyprlandSettings.qml). It counts down and puts the old settings back when
// nobody answers, so a mode the screen can't show doesn't leave you stuck. Keep saves
// the new settings; Revert (or Esc) goes back at once.
Scope {
    id: root

    readonly property bool open: HyprlandSettings.pendingName !== "" && HyprlandSettings.countdown > 0

    PanelLoader {
        id: loader
        shown: root.open

        PanelWindow {
            id: window

            screen: Quickshell.screens.find(s => s.name === HyprlandSettings.pendingName) ?? Quickshell.screens[0]
            anchors.top: true
            anchors.bottom: true
            anchors.left: true
            anchors.right: true
            exclusionMode: ExclusionMode.Ignore
            color: "transparent"
            mask: Region { item: card }

            WlrLayershell.namespace: "hi-shell-display-confirm"
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.keyboardFocus: root.open ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None

            Shortcut {
                sequence: "Escape"
                onActivated: HyprlandSettings.revertPending()
            }

            Rectangle {
                id: card

                anchors.horizontalCenter: parent.horizontalCenter
                anchors.top: parent.top
                anchors.topMargin: 72
                width: 400
                implicitHeight: content.implicitHeight + 40
                height: implicitHeight
                radius: Appearance.rounding.extraLarge
                color: Colors.m3surfaceContainerHigh
                border.width: 1
                border.color: Qt.alpha(Colors.m3outlineVariant, 0.6)

                opacity: loader.revealed ? 1 : 0
                scale: loader.revealed ? 1 : 0.9
                transformOrigin: Item.Top
                Behavior on opacity { EffectAnim {} }
                Behavior on scale { SpringAnim {} }

                ColumnLayout {
                    id: content
                    anchors.fill: parent
                    anchors.margins: 20
                    spacing: 14

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 14

                        CircularProgress {
                            implicitWidth: 52
                            implicitHeight: 52
                            lineWidth: 4
                            animated: false
                            value: HyprlandSettings.countdown / HyprlandSettings.confirmSeconds

                            StyledText {
                                anchors.centerIn: parent
                                text: HyprlandSettings.countdown
                                font.pixelSize: Appearance.font.size.titleMedium
                                font.weight: Font.Medium
                            }
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 2

                            StyledText {
                                Layout.fillWidth: true
                                text: Translation.tr("Keep these display settings?")
                                font.pixelSize: Appearance.font.size.titleMedium
                                font.weight: Font.Medium
                                wrapMode: Text.Wrap
                            }
                            StyledText {
                                Layout.fillWidth: true
                                text: Translation.tr("%1 goes back to how it was in %2 s").arg(HyprlandSettings.pendingName).arg(HyprlandSettings.countdown)
                                color: Colors.m3onSurfaceVariant
                                wrapMode: Text.Wrap
                            }
                        }
                    }

                    RowLayout {
                        Layout.alignment: Qt.AlignRight
                        spacing: 8

                        M3Button {
                            tonal: true
                            icon: "undo"
                            text: Translation.tr("Revert")
                            onClicked: HyprlandSettings.revertPending()
                        }
                        M3Button {
                            icon: "check"
                            text: Translation.tr("Keep")
                            onClicked: HyprlandSettings.keepPending()
                        }
                    }
                }
            }
        }
    }
}
