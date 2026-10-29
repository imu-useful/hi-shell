import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.common
import qs.common.widgets
import qs.services
import qs.modules.notifications

// Notification history grouped by app (newest group first). Groups with more
// than two notifications collapse; opening the sidebar marks everything read.
ColumnLayout {
    id: root

    // [{ app, items: [Notif] }]
    readonly property var groups: {
        const map = new Map();
        for (const n of Notifications.list) {
            if (!map.has(n.appName))
                map.set(n.appName, []);
            map.get(n.appName).push(n);
        }
        return [...map].map(([app, items]) => ({ app, items }));
    }
    property var expandedApps: ({})

    spacing: 8

    RowLayout {
        Layout.fillWidth: true

        StyledText {
            Layout.fillWidth: true
            text: Notifications.list.length === 0 ? "" : Translation.trn("%1 notification", "%1 notifications", Notifications.list.length)
            font.pixelSize: Appearance.font.size.labelMedium
            color: Colors.m3onSurfaceVariant
        }
        Chip {
            icon: Notifications.dnd ? "notifications_off" : "do_not_disturb_on"
            text: Translation.tr("Do not disturb")
            selected: Notifications.dnd
            onClicked: Notifications.dnd = !Notifications.dnd
        }
        Chip {
            visible: Notifications.list.length > 0
            icon: "clear_all"
            text: Translation.tr("Clear")
            onClicked: Notifications.clear()
        }
    }

    StyledFlickable {
        Layout.fillWidth: true
        Layout.fillHeight: true
        contentHeight: list.implicitHeight

        ColumnLayout {
            id: list
            width: parent.width
            spacing: 12

            // Empty state: a game to play (sidebar.game: Chrome's T-rex, snake or minesweeper).
            Loader {
                visible: Notifications.list.length === 0
                active: visible
                Layout.fillWidth: true
                Layout.topMargin: 16
                sourceComponent: ({ snake: snake, minesweeper: minesweeper })[Config.options.sidebar.game] ?? dino
            }
            Component { id: dino; DinoGame {} }
            Component { id: snake; SnakeGame {} }
            Component { id: minesweeper; MinesweeperGame {} }

            Repeater {
                model: ScriptModel {
                    values: root.groups
                    objectProp: "app"
                }

                ColumnLayout {
                    id: group

                    required property var modelData
                    readonly property bool collapsible: modelData.items.length > 2
                    readonly property bool expanded: root.expandedApps[modelData.app] ?? false

                    Layout.fillWidth: true
                    spacing: 4

                    RowLayout {
                        Layout.fillWidth: true
                        Layout.leftMargin: 4

                        StyledText {
                            Layout.fillWidth: true
                            text: group.modelData.app
                            font.pixelSize: Appearance.font.size.labelMedium
                            font.weight: Font.Medium
                            color: Colors.m3primary
                        }
                        Chip {
                            visible: group.collapsible
                            implicitHeight: 26
                            text: group.expanded ? Translation.tr("Show less") : `+${group.modelData.items.length - 2}`
                            onClicked: {
                                const next = Object.assign({}, root.expandedApps);
                                next[group.modelData.app] = !group.expanded;
                                root.expandedApps = next;
                            }
                        }
                        Rectangle {
                            implicitWidth: 26
                            implicitHeight: 26
                            radius: 13
                            color: "transparent"
                            MaterialIcon {
                                anchors.centerIn: parent
                                icon: "close"
                                iconSize: 16
                            }
                            StateLayer {
                                onClicked: Notifications.erase(group.modelData.items.map(n => n.uid))
                            }
                        }
                    }

                    Repeater {
                        model: ScriptModel {
                            values: group.expanded || !group.collapsible ? group.modelData.items : group.modelData.items.slice(0, 2)
                        }

                        NotificationCard {
                            required property var modelData
                            Layout.fillWidth: true
                            notif: modelData
                        }
                    }
                }
            }
        }
    }
}
