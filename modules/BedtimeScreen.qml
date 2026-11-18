import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import qs.common
import qs.common.widgets
import qs.common.shapes
import qs.services

// The full-screen "time to sleep" reminder (services/Bedtime.qml shows it). It covers every
// screen; the buttons are on the focused one. Arrows + Enter or a click; Esc = later.
Scope {
    id: root

    readonly property bool open: Bedtime.showing
    property int current: 0

    readonly property var actions: [
        { icon: "snooze", text: Translation.tr("In %1 min").arg(Config.options.bedtime.snoozeMinutes), shape: "cookie9", run: () => Bedtime.snooze() },
        { icon: "event_busy", text: Translation.tr("Not today"), shape: "clover4", run: () => Bedtime.skip() },
        { icon: "bedtime", text: Translation.tr("Sleep"), shape: "sunny", run: () => Bedtime.suspend() },
        { icon: "power_settings_new", text: Translation.tr("Power off"), shape: "cookie12", run: () => Bedtime.poweroff() }
    ]

    function activate(index) {
        actions[index].run();
    }

    onOpenChanged: if (open) current = 0

    // The time on the screen, a minute at a time.
    property date now: new Date()
    Timer {
        running: root.open
        interval: 10000
        repeat: true
        triggeredOnStart: true
        onTriggered: root.now = new Date()
    }

    Variants {
        model: Quickshell.screens

        PanelLoader {
            id: loader
            required property var modelData
            readonly property bool main: modelData.name === (Hyprland.focusedMonitor?.name ?? Quickshell.screens[0]?.name)
            shown: root.open

            PanelWindow {
                screen: loader.modelData
                anchors.top: true
                anchors.bottom: true
                anchors.left: true
                anchors.right: true
                exclusionMode: ExclusionMode.Ignore
                color: "transparent"

                WlrLayershell.namespace: "hi-shell-bedtime"
                WlrLayershell.layer: WlrLayer.Overlay
                WlrLayershell.keyboardFocus: root.open && loader.main ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

                // Nearly opaque: the point is to stop, not to keep watching what's behind.
                Rectangle {
                    anchors.fill: parent
                    color: Qt.alpha(Colors.m3surface, 0.92)
                    opacity: loader.revealed ? 1 : 0
                    Behavior on opacity { EffectAnim {} }

                    // Clicks don't fall through to the windows behind.
                    MouseArea {
                        anchors.fill: parent
                    }
                }

                Item {
                    anchors.fill: parent
                    focus: loader.main
                    Keys.onPressed: event => {
                        const n = root.actions.length;
                        if (event.key === Qt.Key_Escape)
                            Bedtime.snooze();
                        else if (event.key === Qt.Key_Left || event.key === Qt.Key_Backtab)
                            root.current = (root.current + n - 1) % n;
                        else if (event.key === Qt.Key_Right || event.key === Qt.Key_Tab)
                            root.current = (root.current + 1) % n;
                        else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Space)
                            root.activate(root.current);
                        else
                            return;
                        event.accepted = true;
                    }
                }

                ColumnLayout {
                    anchors.centerIn: parent
                    spacing: 48
                    opacity: loader.revealed ? 1 : 0
                    scale: loader.revealed ? 1 : 0.85
                    Behavior on opacity { EffectAnim {} }
                    Behavior on scale { SpringAnim {} }

                    ColumnLayout {
                        Layout.alignment: Qt.AlignHCenter
                        spacing: 8

                        Item {
                            Layout.alignment: Qt.AlignHCenter
                            Layout.bottomMargin: 16
                            implicitWidth: 112
                            implicitHeight: 112
                            MaterialShape {
                                anchors.fill: parent
                                shape: "cookie12"
                                color: Colors.m3tertiaryContainer
                            }
                            MaterialIcon {
                                anchors.centerIn: parent
                                icon: "bedtime"
                                fill: 1
                                iconSize: 52
                                color: Colors.m3onTertiaryContainer
                            }
                        }
                        StyledText {
                            Layout.alignment: Qt.AlignHCenter
                            text: Qt.formatTime(root.now, "HH:mm")
                            font.pixelSize: Appearance.font.size.displayLarge
                            font.weight: Font.Medium
                            color: Colors.m3primary
                        }
                        StyledText {
                            Layout.alignment: Qt.AlignHCenter
                            text: Translation.tr("Time to sleep, %1").arg(Quickshell.env("USER"))
                            font.pixelSize: Appearance.font.size.headlineMedium
                            font.weight: Font.Medium
                        }
                        StyledText {
                            Layout.alignment: Qt.AlignHCenter
                            text: Translation.tr("Save your work and get some rest. Tomorrow goes better after a good night.")
                            color: Colors.m3onSurfaceVariant
                        }
                    }

                    Row {
                        visible: loader.main
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
                                    width: 112
                                    height: 112
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    scale: action.selected ? 1.08 : 1
                                    Behavior on scale { SpatialAnim { duration: Appearance.anim.normal } }

                                    MaterialShape {
                                        anchors.fill: parent
                                        shape: action.selected ? "circle" : action.modelData.shape
                                        color: action.selected ? Colors.m3primary : Colors.m3secondaryContainer
                                        Behavior on color { ColorAnim {} }
                                    }
                                    MaterialIcon {
                                        anchors.centerIn: parent
                                        icon: action.modelData.icon
                                        fill: action.selected ? 1 : 0
                                        iconSize: 42
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
}
