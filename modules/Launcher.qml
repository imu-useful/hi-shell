import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import Quickshell.Wayland
import qs.common
import qs.modules.launcher

// Spotlight-style app launcher.
// Toggle: Hyprland global shortcut "hi-shell:launcherToggle"
//         or `qs -c hi-shell ipc call launcher toggle`.
Scope {
    id: root

    property bool open: false
    property string query: ""

    readonly property var results: filterApps(query)

    function toggle() {
        open = !open;
    }

    function close() {
        open = false;
    }

    // Lower score = better match; -1 = no match.
    function scoreApp(app, q) {
        const name = app.name.toLowerCase();
        if (name.startsWith(q))
            return 0;
        if (name.split(/[\s\-_.]+/).some(w => w.startsWith(q)))
            return 1;
        if (name.includes(q))
            return 2;
        const extra = [app.genericName, app.comment, app.id, ...app.keywords, ...app.categories].join(" ").toLowerCase();
        if (extra.includes(q))
            return 3;
        return -1;
    }

    function filterApps(text) {
        const apps = DesktopEntries.applications.values.filter(a => !a.noDisplay);
        const q = text.trim().toLowerCase();
        if (q === "")
            return apps.sort((a, b) => a.name.localeCompare(b.name));
        return apps.map(a => ({ app: a, score: scoreApp(a, q) }))
            .filter(r => r.score >= 0)
            .sort((a, b) => a.score - b.score || a.app.name.localeCompare(b.app.name))
            .map(r => r.app);
    }

    function launch(app) {
        if (!app)
            return;
        if (app.runInTerminal)
            Quickshell.execDetached([Style.terminal, "-e", ...app.command]);
        else
            app.execute();
        close();
    }

    GlobalShortcut {
        appid: "hi-shell"
        name: "launcherToggle"
        description: "Toggle the hi-shell app launcher"
        onPressed: root.toggle()
    }

    IpcHandler {
        target: "launcher"

        function toggle(): void {
            root.toggle();
        }
        function open(): void {
            root.open = true;
        }
        function close(): void {
            root.close();
        }
    }

    PanelWindow {
        id: window

        // Open on the monitor that currently has focus.
        screen: Quickshell.screens.find(s => s.name === Hyprland.focusedMonitor?.name) ?? Quickshell.screens[0]
        visible: root.open || card.opacity > 0

        anchors.top: true
        margins.top: screen ? screen.height * 0.18 : 0
        implicitWidth: 600
        implicitHeight: card.implicitHeight
        color: "transparent"

        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.namespace: "hi-shell-launcher"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: root.open ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

        // Clicking anywhere outside the launcher closes it.
        HyprlandFocusGrab {
            windows: [window]
            active: root.open
            onCleared: root.close()
        }

        Connections {
            target: root
            function onOpenChanged() {
                if (root.open) {
                    root.query = "";
                    search.text = "";
                    list.currentIndex = 0;
                    search.forceActiveFocus();
                }
            }
        }

        Rectangle {
            id: card

            width: parent.width
            implicitHeight: column.implicitHeight + 24
            radius: 28
            // Translucent so the compositor blur (see hypr/hi-shell.lua) shows through.
            color: Qt.alpha(Colors.m3surfaceContainer, 0.88)
            border.width: 1
            border.color: Colors.m3outlineVariant

            opacity: root.open ? 1 : 0
            scale: root.open ? 1 : 0.95
            transformOrigin: Item.Top
            Behavior on opacity { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
            Behavior on scale { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }

            ColumnLayout {
                id: column
                anchors.fill: parent
                anchors.margins: 12
                spacing: 8

                // Search field (M3 search bar)
                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: 56
                    radius: Style.radiusFull
                    color: Colors.m3surfaceContainerHighest

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 18
                        anchors.rightMargin: 18
                        spacing: 12

                        Text {
                            text: "search"
                            font.family: Style.iconFont
                            font.pixelSize: 24
                            color: Colors.m3onSurfaceVariant
                        }

                        TextInput {
                            id: search
                            Layout.fillWidth: true
                            font.family: Style.fontFamily
                            font.pixelSize: 16
                            color: Colors.m3onSurface
                            selectionColor: Colors.m3primary
                            selectedTextColor: Colors.m3onPrimary
                            clip: true

                            onTextChanged: {
                                root.query = text;
                                list.currentIndex = 0;
                            }

                            Keys.onEscapePressed: root.close()
                            Keys.onReturnPressed: root.launch(root.results[list.currentIndex])
                            Keys.onEnterPressed: root.launch(root.results[list.currentIndex])
                            Keys.onUpPressed: list.decrementCurrentIndex()
                            Keys.onDownPressed: list.incrementCurrentIndex()
                            Keys.onTabPressed: list.incrementCurrentIndex()
                            Keys.onBacktabPressed: list.decrementCurrentIndex()

                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                visible: search.text === ""
                                text: "Search apps"
                                font: search.font
                                color: Colors.m3onSurfaceVariant
                            }
                        }
                    }
                }

                ListView {
                    id: list
                    Layout.fillWidth: true
                    implicitHeight: Math.min(count, 8) * 52 + Math.max(0, Math.min(count, 8) - 1) * spacing
                    visible: count > 0
                    clip: true
                    spacing: 2
                    model: root.results
                    highlightMoveDuration: 0
                    boundsBehavior: Flickable.StopAtBounds

                    delegate: AppItem {
                        width: list.width
                        selected: ListView.isCurrentItem
                        onHovered: list.currentIndex = index
                        onActivated: root.launch(modelData)
                    }
                }

                Text {
                    Layout.fillWidth: true
                    Layout.margins: 12
                    visible: list.count === 0
                    text: "No apps match “" + root.query + "”"
                    horizontalAlignment: Text.AlignHCenter
                    font.family: Style.fontFamily
                    font.pixelSize: 13
                    color: Colors.m3onSurfaceVariant
                }
            }
        }
    }
}
