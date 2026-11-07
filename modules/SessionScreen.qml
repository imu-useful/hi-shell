import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import qs.common
import qs.common.widgets
import qs.common.shapes
import qs.services

// Full-screen session menu: lock, log out, suspend, reboot, power off.
// Arrow keys + Enter, or click; Esc / clicking outside closes.
// Toggle: the bar's power button or `qs -c hi-shell ipc call session toggleScreen`.
Scope {
    id: root

    readonly property bool open: ShellState.sessionOpen
    property int current: 0

    // The "Reboot to..." list instead of the actions.
    property bool picking: false
    property int pickIndex: 0

    readonly property var actions: [
        { icon: "lock", text: Translation.tr("Lock"), shape: "cookie9", run: () => Session.lock() },
        { icon: "logout", text: Translation.tr("Log out"), shape: "clover4", run: () => Session.logout() },
        { icon: "bedtime", text: Translation.tr("Suspend"), shape: "sunny", run: () => Session.suspend() },
        { icon: "restart_alt", text: Translation.tr("Reboot"), shape: "flower", run: () => Session.reboot() },
        ...(BootEntries.available ? [{ icon: "devices", text: Translation.tr("Reboot to…"), shape: "pill", pick: true }] : []),
        { icon: "power_settings_new", text: Translation.tr("Power off"), shape: "cookie12", run: () => Session.poweroff() }
    ]

    function close() {
        ShellState.sessionOpen = false;
    }
    function activate(index) {
        if (actions[index].pick) {
            pickIndex = 0;
            picking = true;
            return;
        }
        close();
        // Let the overlay go before the screen locks / the session ends.
        Qt.callLater(() => actions[index].run());
    }

    function pickEntry(index) {
        const entry = BootEntries.entries[index];
        close();
        Qt.callLater(() => BootEntries.rebootInto(entry));
    }

    onOpenChanged: {
        if (open) {
            current = 0;
            picking = false;
            BootEntries.refresh();
        }
    }

    PanelLoader {
        id: loader
        shown: root.open

        PanelWindow {
            id: window

            screen: Quickshell.screens.find(s => s.name === Hyprland.focusedMonitor?.name) ?? Quickshell.screens[0]
            anchors.top: true
            anchors.bottom: true
            anchors.left: true
            anchors.right: true
            exclusionMode: ExclusionMode.Ignore
            color: "transparent"

            WlrLayershell.namespace: "hi-shell-session"
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.keyboardFocus: root.open ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

            Rectangle {
                anchors.fill: parent
                color: Qt.alpha(Colors.m3surface, 0.6)
                opacity: loader.revealed ? 1 : 0
                Behavior on opacity { EffectAnim {} }

                MouseArea {
                    anchors.fill: parent
                    onClicked: root.close()
                }
            }

            Item {
                anchors.fill: parent
                focus: true
                Keys.onPressed: event => {
                    const n = BootEntries.entries.length;
                    if (root.picking) {
                        if (event.key === Qt.Key_Escape)
                            root.picking = false;
                        else if (event.key === Qt.Key_Up || event.key === Qt.Key_Backtab)
                            root.pickIndex = (root.pickIndex + n - 1) % n;
                        else if (event.key === Qt.Key_Down || event.key === Qt.Key_Tab)
                            root.pickIndex = (root.pickIndex + 1) % n;
                        else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Space)
                            root.pickEntry(root.pickIndex);
                        else
                            return;
                        event.accepted = true;
                        return;
                    }
                    if (event.key === Qt.Key_Escape)
                        root.close();
                    else if (event.key === Qt.Key_Left || event.key === Qt.Key_Backtab)
                        root.current = (root.current + root.actions.length - 1) % root.actions.length;
                    else if (event.key === Qt.Key_Right || event.key === Qt.Key_Tab)
                        root.current = (root.current + 1) % root.actions.length;
                    else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Space)
                        root.activate(root.current);
                    else
                        return;
                    event.accepted = true;
                }
            }

            ColumnLayout {
                anchors.centerIn: parent
                spacing: 40
                opacity: loader.revealed ? 1 : 0
                scale: loader.revealed ? 1 : 0.85
                Behavior on opacity { EffectAnim {} }
                Behavior on scale { SpringAnim {} }

                ColumnLayout {
                    Layout.alignment: Qt.AlignHCenter
                    spacing: 4
                    StyledText {
                        Layout.alignment: Qt.AlignHCenter
                        text: Translation.tr("Goodbye, %1?").arg(Quickshell.env("USER"))
                        font.pixelSize: Appearance.font.size.headlineMedium
                        font.weight: Font.Medium
                    }
                    StyledText {
                        Layout.alignment: Qt.AlignHCenter
                        text: Translation.tr("Up %1").arg(SystemStats.uptimeText)
                        color: Colors.m3onSurfaceVariant
                    }
                }

                Column {
                    visible: root.picking
                    Layout.alignment: Qt.AlignHCenter
                    spacing: 6

                    Repeater {
                        model: BootEntries.entries

                        Rectangle {
                            id: pick
                            required property var modelData
                            required property int index
                            readonly property bool selected: root.pickIndex === index
                            width: 420
                            height: 56
                            radius: Appearance.rounding.full
                            color: selected ? Colors.m3primary : Colors.m3secondaryContainer
                            Behavior on color { ColorAnim {} }

                            Row {
                                anchors.verticalCenter: parent.verticalCenter
                                anchors.left: parent.left
                                anchors.leftMargin: 22
                                spacing: 14
                                MaterialIcon {
                                    anchors.verticalCenter: parent.verticalCenter
                                    icon: pick.modelData.icon
                                    iconSize: 24
                                    color: pick.selected ? Colors.m3onPrimary : Colors.m3onSecondaryContainer
                                }
                                StyledText {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: pick.modelData.title
                                    font.pixelSize: Appearance.font.size.titleMedium
                                    color: pick.selected ? Colors.m3onPrimary : Colors.m3onSecondaryContainer
                                }
                            }
                            MouseArea {
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onEntered: root.pickIndex = pick.index
                                onClicked: root.pickEntry(pick.index)
                            }
                        }
                    }
                }

                Row {
                    visible: !root.picking
                    Layout.alignment: Qt.AlignHCenter
                    spacing: 28

                    Repeater {
                        model: root.actions

                        Column {
                            id: action

                            required property var modelData
                            required property int index
                            readonly property bool selected: root.current === index

                            spacing: 12

                            Item {
                                width: 120
                                height: 120
                                anchors.horizontalCenter: parent.horizontalCenter
                                scale: action.selected ? 1.08 : 1
                                Behavior on scale { SpatialAnim { duration: Appearance.anim.normal } }

                                MaterialShape {
                                    anchors.fill: parent
                                    // Morphs to a circle when selected.
                                    shape: action.selected ? "circle" : action.modelData.shape
                                    color: action.selected ? Colors.m3primary : Colors.m3secondaryContainer
                                    Behavior on color { ColorAnim {} }
                                }
                                MaterialIcon {
                                    anchors.centerIn: parent
                                    icon: action.modelData.icon
                                    fill: action.selected ? 1 : 0
                                    iconSize: 44
                                    color: action.selected ? Colors.m3onPrimary : Colors.m3onSecondaryContainer
                                }
                                MouseArea {
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onEntered: root.current = action.index
                                    onClicked: root.activate(action.index)
                                }
                            }

                            StyledText {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: action.modelData.text
                                font.pixelSize: Appearance.font.size.titleMedium
                                font.weight: action.selected ? Font.DemiBold : Font.Normal
                                color: action.selected ? Colors.m3primary : Colors.m3onSurface
                            }
                        }
                    }
                }
            }
        }
    }
}
