import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs.common
import qs.common.widgets
import qs.common.shapes
import qs.services

// A new version of the shell is out: shown once per start, after the first update check.
// Release channel: the release and its notes. Git channel: a new commit (the list of them).
// Update runs update.sh and opens Settings > About, where its output shows; Later (or Esc) closes it until the next start.
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
            color: Qt.alpha("black", loader.revealed ? 0.5 : 0)
            Behavior on color { ColorAnim {} }

            WlrLayershell.namespace: "hi-shell-update"
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.keyboardFocus: root.open ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

            Shortcut {
                sequence: "Escape"
                onActivated: root.close()
            }

            Rectangle {
                id: card

                anchors.centerIn: parent
                width: Math.min(parent.width - 80, 680)
                height: Math.min(parent.height - 100, 560)
                radius: Appearance.shape.panel
                color: Colors.m3surfaceContainerLow
                border.width: Appearance.edge
                border.color: Qt.alpha(Colors.m3outlineVariant, 0.6)

                opacity: loader.revealed ? 1 : 0
                scale: loader.revealed ? 1 : 0.85
                Behavior on opacity { EffectAnim {} }
                Behavior on scale { SpringAnim {} }

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 32
                    spacing: 16

                    Item {
                        Layout.alignment: Qt.AlignHCenter
                        implicitWidth: 104
                        implicitHeight: 104
                        MaterialShape {
                            anchors.fill: parent
                            shape: "cookie9"
                            color: Colors.m3primaryContainer
                        }
                        MaterialIcon {
                            anchors.centerIn: parent
                            icon: "system_update"
                            fill: 1
                            iconSize: 48
                            color: Colors.m3onPrimaryContainer
                        }
                    }

                    StyledText {
                        Layout.fillWidth: true
                        horizontalAlignment: Text.AlignHCenter
                        text: root.title
                        font.family: Appearance.font.title
                        font.pixelSize: 34
                        wrapMode: Text.Wrap
                    }
                    StyledText {
                        Layout.fillWidth: true
                        horizontalAlignment: Text.AlignHCenter
                        text: root.release ? Translation.tr("A new release of hi-shell is ready to install")
                            : Translation.tr("The latest main has changes you don't have yet")
                        color: Colors.m3onSurfaceVariant
                        wrapMode: Text.Wrap
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        visible: root.notes !== ""
                        radius: Appearance.rounding.large
                        color: Colors.m3surfaceContainer
                        clip: true

                        Flickable {
                            anchors.fill: parent
                            anchors.margins: 16
                            contentHeight: notesText.implicitHeight
                            boundsBehavior: Flickable.StopAtBounds

                            StyledText {
                                id: notesText
                                width: parent.width
                                text: root.notes
                                wrapMode: Text.Wrap
                                elide: Text.ElideNone
                            }
                        }
                    }
                    Item {
                        Layout.fillHeight: true
                        visible: root.notes === ""
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8

                        Item { Layout.fillWidth: true }
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
                                ShellState.settingsPage = "about";
                                ShellState.settingsOpen = true;
                            }
                        }
                    }
                }
            }
        }
    }
}
