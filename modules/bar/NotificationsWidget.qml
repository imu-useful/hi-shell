import QtQuick
import QtQuick.Layouts
import qs.common
import qs.common.widgets
import qs.services

// Bell with the unread count. Left click = mark all read, right click = do not
// disturb. Hover for the latest notifications.
BarWidget {
    id: root

    clickable: true
    active: Notifications.dnd
    padding: 6
    contentWidth: row.implicitWidth
    contentHeight: row.implicitHeight
    onClicked: mouse => mouse.button === Qt.RightButton ? Notifications.dnd = !Notifications.dnd : Notifications.markAllRead()

    Row {
        id: row
        anchors.centerIn: parent
        spacing: 2

        MaterialIcon {
            icon: Notifications.dnd ? "notifications_off" : Notifications.unread > 0 ? "notifications_unread" : "notifications"
            iconSize: 18
            fill: Notifications.unread > 0 ? 1 : 0
            color: root.active ? Colors.m3onSecondaryContainer : Colors.m3onSurface
        }

        Rectangle {
            visible: Notifications.unread > 0 && !root.vertical
            anchors.verticalCenter: parent.verticalCenter
            implicitWidth: Math.max(18, count.implicitWidth + 8)
            implicitHeight: 18
            radius: 9
            color: Colors.m3primary

            StyledText {
                id: count
                anchors.centerIn: parent
                text: Notifications.unread > 99 ? "99+" : Notifications.unread
                font.pixelSize: Appearance.font.size.labelSmall
                font.weight: Font.DemiBold
                color: Colors.m3onPrimary
            }
        }
    }

    StyledPopup {
        target: root
        hovered: root.hovered
        edge: root.popupEdge

        ColumnLayout {
            width: 300
            spacing: 10

            StyledText {
                text: Notifications.list.length === 0 ? "No notifications" : Notifications.unread > 0 ? `${Notifications.unread} unread` : "Notifications"
                font.pixelSize: Appearance.font.size.titleMedium
                font.weight: Font.Medium
            }

            Repeater {
                model: Notifications.list.slice(0, 4)

                ColumnLayout {
                    required property var modelData
                    Layout.fillWidth: true
                    spacing: 0

                    StyledText {
                        Layout.fillWidth: true
                        text: `${modelData.appName} · ${Notifications.relativeTime(modelData.time)}`
                        font.pixelSize: Appearance.font.size.labelSmall
                        color: Colors.m3onSurfaceVariant
                    }
                    StyledText {
                        Layout.fillWidth: true
                        text: modelData.summary
                        font.weight: modelData.read ? Font.Normal : Font.Medium
                    }
                }
            }

            RowLayout {
                spacing: 6
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
        }
    }
}
