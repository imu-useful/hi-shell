import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs.common
import qs.common.widgets
import qs.services

// A new version of the shell is out: shown once per start, after the first update check.
// Release channel: the release and its notes. Git channel: a new commit (the list of them).
// Update opens update.sh in a terminal; Later (or Esc) closes it until the next start.
// Turned off in Settings > About.
Scope {
    id: root

    readonly property bool release: Config.options.update.channel === "release"
    property bool dismissed: false
    // `qs -c hi-shell ipc call updateDialog preview` shows it with sample text
    property bool preview: false
    readonly property bool open: preview || (Config.options.update.notify && !dismissed && Updates.shellChecked && Updates.shellBehind > 0)
    readonly property string notes: preview ? "Update window: what the update brings, Update and Later\nSettings: the window can be turned off in About" : Updates.shellNotes

    IpcHandler {
        target: "updateDialog"

        function preview(): void {
            root.preview = true;
        }
    }

    readonly property string title: release ? Translation.tr("New release %1").arg(Updates.shellRelease || "v1.7.0")
        : (preview || Updates.shellBehind > 1) ? Translation.tr("%1 new commits are out").arg(preview ? 2 : Updates.shellBehind)
        : Translation.tr("A new commit is out")

    function close(): void {
        dismissed = true;
        preview = false;
    }

    PanelLoader {
        id: loader
        shown: root.open

        PanelWindow {
            id: window

            screen: Quickshell.screens[0]
            anchors.top: true
            anchors.bottom: true
            anchors.left: true
            anchors.right: true
            exclusionMode: ExclusionMode.Ignore
            color: "transparent"
            mask: Region { item: card }

            WlrLayershell.namespace: "hi-shell-update"
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.keyboardFocus: root.open ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None

            Shortcut {
                sequence: "Escape"
                onActivated: root.close()
            }

            Rectangle {
                id: card

                anchors.centerIn: parent
                width: 440
                implicitHeight: content.implicitHeight + 40
                height: implicitHeight
                radius: Appearance.rounding.extraLarge
                color: Colors.m3surfaceContainerHigh
                border.width: 1
                border.color: Qt.alpha(Colors.m3outlineVariant, 0.6)

                opacity: loader.revealed ? 1 : 0
                scale: loader.revealed ? 1 : 0.9
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

                        MaterialIcon {
                            icon: "system_update"
                            iconSize: 36
                            color: Colors.m3primary
                        }
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 2
                            StyledText {
                                Layout.fillWidth: true
                                text: root.title
                                font.pixelSize: Appearance.font.size.titleMedium
                                font.weight: Font.Medium
                                wrapMode: Text.Wrap
                            }
                            StyledText {
                                Layout.fillWidth: true
                                text: root.release ? Translation.tr("A new release of hi-shell is ready to install")
                                    : Translation.tr("The latest main has changes you don't have yet")
                                color: Colors.m3onSurfaceVariant
                                wrapMode: Text.Wrap
                            }
                        }
                    }

                    StyledText {
                        Layout.fillWidth: true
                        visible: text !== ""
                        text: root.notes
                        maximumLineCount: 10
                        elide: Text.ElideRight
                        wrapMode: Text.Wrap
                        color: Colors.m3onSurface
                    }

                    RowLayout {
                        Layout.alignment: Qt.AlignRight
                        spacing: 8

                        M3Button {
                            tonal: true
                            text: Translation.tr("Later")
                            onClicked: root.close()
                        }
                        M3Button {
                            icon: "system_update_alt"
                            text: Translation.tr("Update")
                            onClicked: {
                                root.close();
                                Updates.updateShell();
                            }
                        }
                    }
                }
            }
        }
    }
}
