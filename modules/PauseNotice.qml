import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs.common
import qs.common.widgets
import qs.common.shapes
import qs.services

// The announcement of the break: the final release 2.3.0, and no updates until February 2027.
// Shown once per release: at the start after an update, or, on a fresh install, right after the welcome.
// "Got it" (or Escape) writes the version to ~/.local/state/hi-shell/pause-notice-seen, so it doesn't come back.
// `qs -c hi-shell ipc call pauseNotice open` shows it again (a preview: nothing is written).
Scope {
    id: root

    readonly property string version: "2.3.0"
    property bool preview: false
    property bool dismissed: false
    // The seen-file is read and holds another version (or is missing)
    property bool unseen: false
    // No welcome-done yet: the welcome is going to run, and the notice waits for it
    property bool welcomePending: false
    readonly property bool open: preview || (unseen && !dismissed && !welcomePending && Fullscreen.screens.length === 0)

    function close(): void {
        if (!preview && !dismissed)
            seenFile.setText(version + "\n");
        dismissed = true;
        preview = false;
    }

    Connections {
        target: ShellState
        function onWelcomeFinished() {
            root.welcomePending = false;
        }
    }

    FileView {
        id: seenFile
        path: `${Paths.state}/pause-notice-seen`
        printErrors: false
        onLoaded: root.unseen = text().trim() !== root.version
        onLoadFailed: root.unseen = true
    }

    FileView {
        path: `${Paths.state}/welcome-done`
        printErrors: false
        onLoadFailed: error => {
            if (error === FileViewError.FileNotFound)
                root.welcomePending = true;
        }
    }

    IpcHandler {
        target: "pauseNotice"

        function open(): void {
            root.preview = true;
        }
        function close(): void {
            root.close();
        }
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

            WlrLayershell.namespace: "hi-shell-pause"
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.keyboardFocus: root.open ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

            Shortcut {
                sequences: ["Escape", "Return", "Enter"]
                onActivated: root.close()
            }

            Rectangle {
                id: card

                anchors.centerIn: parent
                width: Math.min(parent.width - 80, 620)
                height: Math.min(parent.height - 100, content.implicitHeight + 64)
                radius: Appearance.shape.panel
                color: Colors.m3surfaceContainerLow
                border.width: Appearance.edge
                border.color: Qt.alpha(Colors.m3outlineVariant, 0.6)

                opacity: loader.revealed ? 1 : 0
                scale: loader.revealed ? 1 : 0.85
                Behavior on opacity { EffectAnim {} }
                Behavior on scale { SpringAnim {} }

                ColumnLayout {
                    id: content
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
                            icon: "bedtime"
                            fill: 1
                            iconSize: 48
                            color: Colors.m3onPrimaryContainer
                        }
                    }

                    StyledText {
                        Layout.fillWidth: true
                        horizontalAlignment: Text.AlignHCenter
                        text: Translation.tr("hi-shell is taking a break")
                        font.family: Appearance.font.title
                        font.pixelSize: 34
                        wrapMode: Text.Wrap
                    }
                    StyledText {
                        Layout.fillWidth: true
                        horizontalAlignment: Text.AlignHCenter
                        text: Translation.tr("Version 2.3.0 is the final release for now")
                        color: Colors.m3onSurfaceVariant
                        wrapMode: Text.Wrap
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        implicitHeight: body.implicitHeight + 32
                        radius: Appearance.rounding.large
                        color: Colors.m3surfaceContainer

                        StyledText {
                            id: body
                            anchors.fill: parent
                            anchors.margins: 16
                            text: Translation.tr("There will be no updates until February 2027: I've run out of ideas for what to add, and my subscription is ending.\n\nEverything you have keeps working as it is. Thank you for using hi-shell. See you in February!")
                            wrapMode: Text.Wrap
                            elide: Text.ElideNone
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        Item { Layout.fillWidth: true }
                        M3Button {
                            icon: "check"
                            text: Translation.tr("Got it")
                            onClicked: root.close()
                        }
                    }
                }
            }
        }
    }
}
