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
            text: Notifications.list.length === 0 ? "" : `${Notifications.list.length} notification${Notifications.list.length === 1 ? "" : "s"}`
            font.pixelSize: Appearance.font.size.labelMedium
            color: Colors.m3onSurfaceVariant
        }
        Chip {
            icon: Notifications.dnd ? "notifications_off" : "do_not_disturb_on"
            text: "Do not disturb"
            selected: Notifications.dnd
            onClicked: Notifications.dnd = !Notifications.dnd
        }
        Chip {
            visible: Notifications.list.length > 0
            icon: "clear_all"
            text: "Clear"
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

            // Empty state
            ColumnLayout {
                visible: Notifications.list.length === 0
                Layout.alignment: Qt.AlignHCenter
                Layout.topMargin: 40
                spacing: 8

                MaterialIcon {
                    Layout.alignment: Qt.AlignHCenter
                    icon: "notifications_paused"
                    iconSize: 48
                    color: Colors.m3outline
                }
                StyledText {
                    Layout.alignment: Qt.AlignHCenter
                    text: "Nothing new"
                    color: Colors.m3onSurfaceVariant
                }
            }

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
                            text: group.expanded ? "Show less" : `+${group.modelData.items.length - 2}`
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
                                onClicked: group.modelData.items.forEach(n => Notifications.dismiss(n.uid))
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
