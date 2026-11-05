import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Wayland
import qs.common
import qs.common.widgets
import qs.services

// Full-screen list of every app, as a grid of icons. Type to filter, arrows + Enter or click to
// launch, Esc / a click outside closes.
// Toggle: the dock's apps button or `qs -c hi-shell ipc call appgrid toggle`.
Scope {
    id: root

    readonly property bool open: ShellState.appGridOpen
    property string query: ""

    readonly property var apps: {
        const q = query.trim().toLowerCase();
        const all = DesktopEntries.applications.values.filter(a => !a.noDisplay);
        const found = q === "" ? all : all.filter(a => `${a.name} ${a.genericName} ${a.comment} ${a.keywords.join(" ")}`.toLowerCase().includes(q));
        return found.sort((a, b) => a.name.localeCompare(b.name));
    }

    function toggle() {
        if (!ShellState.appGridOpen)
            ShellState.launcherOpen = false;
        ShellState.appGridOpen = !ShellState.appGridOpen;
    }
    function close() {
        ShellState.appGridOpen = false;
    }
    function launch(app) {
        if (!app)
            return;
        close();
        FocusBlocker.launch(app);
    }

    onOpenChanged: query = ""

    IpcHandler {
        target: "appgrid"

        function toggle(): void {
            root.toggle();
        }
        function open(): void {
            ShellState.appGridOpen = true;
        }
        function close(): void {
            root.close();
        }
    }

    PanelLoader {
        id: loader
        shown: root.open

        PanelWindow {
            screen: Quickshell.screens.find(s => s.name === Hyprland.focusedMonitor?.name) ?? Quickshell.screens[0]
            anchors.top: true
            anchors.bottom: true
            anchors.left: true
            anchors.right: true
            exclusionMode: ExclusionMode.Ignore
            color: "transparent"

            WlrLayershell.namespace: "hi-shell-appgrid"
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.keyboardFocus: root.open ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

            Rectangle {
                anchors.fill: parent
                color: Qt.alpha(Colors.m3surface, 0.94)
                opacity: loader.revealed ? 1 : 0
                Behavior on opacity { EffectAnim {} }

                MouseArea {
                    anchors.fill: parent
                    onClicked: root.close()
                }
            }

            ColumnLayout {
                anchors.fill: parent
                anchors.topMargin: 64
                anchors.bottomMargin: 40
                anchors.leftMargin: 80
                anchors.rightMargin: 80
                spacing: 36
                opacity: loader.revealed ? 1 : 0
                scale: loader.revealed ? 1 : 0.96
                Behavior on opacity { EffectAnim {} }
                Behavior on scale { SpringAnim {} }

                // The search field.
                Rectangle {
                    Layout.alignment: Qt.AlignHCenter
                    Layout.preferredWidth: 460
                    Layout.preferredHeight: 52
                    radius: height / 2
                    color: Colors.m3surfaceContainerHigh

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 18
                        anchors.rightMargin: 18
                        spacing: 12

                        MaterialIcon {
                            icon: "search"
                            iconSize: 22
                            color: Colors.m3onSurfaceVariant
                        }

                        TextInput {
                            id: search
                            Layout.fillWidth: true
                            font.family: Appearance.font.main
                            font.pixelSize: 16
                            color: Colors.m3onSurface
                            selectionColor: Colors.m3primary
                            selectedTextColor: Colors.m3onPrimary
                            clip: true
                            focus: true
                            Component.onCompleted: forceActiveFocus()

                            onTextChanged: {
                                root.query = text;
                                grid.currentIndex = 0;
                            }
                            Keys.onPressed: event => {
                                if (event.key === Qt.Key_Escape)
                                    root.close();
                                else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter)
                                    root.launch(root.apps[grid.currentIndex]);
                                else if (event.key === Qt.Key_Left)
                                    grid.moveCurrentIndexLeft();
                                else if (event.key === Qt.Key_Right)
                                    grid.moveCurrentIndexRight();
                                else if (event.key === Qt.Key_Up)
                                    grid.moveCurrentIndexUp();
                                else if (event.key === Qt.Key_Down)
                                    grid.moveCurrentIndexDown();
                                else
                                    return;
                                event.accepted = true;
                            }

                            StyledText {
                                visible: search.text === ""
                                text: Translation.tr("Search apps")
                                color: Colors.m3onSurfaceVariant
                            }
                        }
                    }
                }

                GridView {
                    id: grid

                    readonly property int columns: Math.max(1, Math.floor(width / 128))

                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    cellWidth: Math.floor(width / columns)
                    cellHeight: 124
                    clip: true
                    model: root.apps
                    currentIndex: 0
                    boundsBehavior: Flickable.StopAtBounds
                    highlightMoveDuration: 0

                    delegate: Item {
                        id: cell

                        required property var modelData
                        required property int index
                        readonly property bool selected: GridView.isCurrentItem

                        width: grid.cellWidth
                        height: grid.cellHeight

                        Rectangle {
                            anchors.fill: parent
                            anchors.margins: 4
                            radius: Appearance.rounding.large
                            color: cell.selected ? Colors.m3secondaryContainer : "transparent"
                            Behavior on color { ColorAnim {} }
                        }

                        Column {
                            anchors.centerIn: parent
                            spacing: 8

                            ThemedIcon {
                                anchors.horizontalCenter: parent.horizontalCenter
                                size: 56
                                source: Quickshell.iconPath(cell.modelData.icon, "application-x-executable")
                            }
                            StyledText {
                                width: cell.width - 20
                                horizontalAlignment: Text.AlignHCenter
                                text: cell.modelData.name
                                elide: Text.ElideRight
                                font.pixelSize: Appearance.font.size.labelMedium
                                color: cell.selected ? Colors.m3onSecondaryContainer : Colors.m3onSurface
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onEntered: grid.currentIndex = cell.index
                            onClicked: root.launch(cell.modelData)
                        }
                    }

                    StyledText {
                        anchors.centerIn: parent
                        visible: root.apps.length === 0
                        text: Translation.tr("No apps found")
                        color: Colors.m3onSurfaceVariant
                    }
                }
            }
        }
    }
}
