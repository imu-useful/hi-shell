import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import qs.common
import qs.common.widgets
import qs.services

// "Steam is blocked" card under the bar when Focus Mode blocks an app (FocusBlocker),
// with the app's icon and when it's allowed again: at the break, or when the session
// ends (a Timer session's last focus period).
Scope {
    id: root

    property string name: ""
    property string icon: ""
    property bool shown: false

    readonly property bool lastPeriod: Focus.sessionProfile.exit === "timer" && Focus.phase.cycle >= (Focus.sessionProfile.timer?.cycles ?? 0)
    readonly property string timeLeft: {
        const s = Focus.remaining;
        return `${Math.floor(s / 60)}:${String(s % 60).padStart(2, "0")}`;
    }

    Connections {
        target: FocusBlocker
        function onBlocked(name, icon) {
            root.name = name;
            root.icon = icon;
            root.shown = true;
            hide.restart();
        }
    }

    Timer {
        id: hide
        interval: 4500
        onTriggered: root.shown = false
    }

    PanelLoader {
        id: loader
        shown: root.shown

        PanelWindow {
            id: window

            readonly property bool atBottom: Config.options.bar.position === "bottom"

            screen: Quickshell.screens.find(s => s.name === Hyprland.focusedMonitor?.name) ?? Quickshell.screens[0]
            anchors.top: !atBottom
            anchors.bottom: atBottom
            // Below the on-screen display, which shows in the same place.
            margins.top: Appearance.sizes.barMargin + 76
            margins.bottom: Appearance.sizes.barMargin + 76
            exclusiveZone: 0
            implicitWidth: card.width + 32
            implicitHeight: card.height + 32
            color: "transparent"
            mask: Region { item: card }

            WlrLayershell.namespace: "hi-shell-focus-toast"
            WlrLayershell.layer: WlrLayer.Overlay

            Rectangle {
                id: card

                anchors.centerIn: parent
                width: Math.max(340, row.implicitWidth + 32)
                height: 76
                radius: Appearance.rounding.extraLarge
                color: Colors.m3surfaceContainerHigh
                border.width: 1
                border.color: Qt.alpha(Colors.m3outlineVariant, 0.6)

                opacity: loader.revealed ? 1 : 0
                scale: loader.revealed ? 1 : 0.85
                Behavior on opacity { EffectAnim {} }
                Behavior on scale { SpringAnim {} }

                RowLayout {
                    id: row
                    anchors.fill: parent
                    anchors.leftMargin: 14
                    anchors.rightMargin: 18
                    spacing: 14

                    // The app's icon with a "blocked" badge.
                    Item {
                        implicitWidth: 48
                        implicitHeight: 48

                        Rectangle {
                            anchors.fill: parent
                            radius: 16
                            color: Colors.m3errorContainer
                        }
                        Image {
                            id: appIcon
                            anchors.centerIn: parent
                            width: 32
                            height: 32
                            sourceSize: Qt.size(64, 64)
                            source: root.icon ? Quickshell.iconPath(root.icon, true) : ""
                            visible: status === Image.Ready
                            opacity: 0.55
                        }
                        MaterialIcon {
                            anchors.centerIn: parent
                            visible: !appIcon.visible
                            icon: "apps"
                            iconSize: 26
                            color: Colors.m3onErrorContainer
                        }
                        Rectangle {
                            anchors.right: parent.right
                            anchors.bottom: parent.bottom
                            anchors.margins: -4
                            width: 24
                            height: 24
                            radius: 12
                            color: Colors.m3error
                            border.width: 2
                            border.color: Colors.m3surfaceContainerHigh
                            MaterialIcon {
                                anchors.centerIn: parent
                                icon: "block"
                                iconSize: 14
                                color: Colors.m3surfaceContainerHigh
                            }
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 2
                        StyledText {
                            text: Translation.tr("%1 is blocked").arg(root.name)
                            font.pixelSize: Appearance.font.size.bodyLarge
                            font.weight: Font.Medium
                        }
                        StyledText {
                            text: root.lastPeriod ? Translation.tr("Available when the session ends, in %1").arg(root.timeLeft)
                                                  : Translation.tr("Available at the break, in %1").arg(root.timeLeft)
                            font.features: { "tnum": 1 }
                            color: Colors.m3onSurfaceVariant
                        }
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    onClicked: root.shown = false
                }
            }
        }
    }
}
