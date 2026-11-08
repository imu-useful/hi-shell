import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.common
import qs.common.widgets
import qs.services

// The notifications that came in, newest first (not their content with "Hide notifications" on).
Tile {
    id: root

    readonly property bool hidden: Config.options.lock.hideNotifs
    readonly property var items: hidden ? [] : Notifications.list

    radius: Appearance.rounding.medium
    bottomRightRadius: Appearance.rounding.extraLarge

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: Appearance.space.lg
        spacing: Appearance.space.md

        StyledText {
            Layout.fillWidth: true
            text: Notifications.list.length > 0
                ? Translation.trn("%1 notification", "%1 notifications", Notifications.list.length)
                : Translation.tr("Notifications")
            color: Colors.m3outline
            font.family: Appearance.font.mono
            font.pixelSize: Appearance.font.size.labelMedium
            font.weight: Font.Medium
        }

        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true

            ColumnLayout {
                anchors.centerIn: parent
                visible: root.items.length === 0
                spacing: Appearance.space.sm

                MaterialIcon {
                    Layout.alignment: Qt.AlignHCenter
                    icon: root.hidden ? "visibility_off" : "notifications_off"
                    iconSize: 48
                    color: Colors.m3outlineVariant
                }
                StyledText {
                    Layout.alignment: Qt.AlignHCenter
                    text: root.hidden ? Translation.tr("Unlock for notifications") : Translation.tr("No notifications")
                    color: Colors.m3outlineVariant
                    font.family: Appearance.font.mono
                }
            }

            ListView {
                anchors.fill: parent
                clip: true
                spacing: Appearance.space.sm
                interactive: contentHeight > height
                model: ScriptModel {
                    values: [...root.items].reverse()
                }

                delegate: Rectangle {
                    id: row
                    required property var modelData
                    width: ListView.view.width
                    height: col.implicitHeight + Appearance.space.md * 2
                    radius: Appearance.rounding.medium
                    color: Appearance.translucent(Colors.m3surfaceContainerHigh)

                    ColumnLayout {
                        id: col
                        anchors.fill: parent
                        anchors.margins: Appearance.space.md
                        spacing: 2

                        RowLayout {
                            Layout.fillWidth: true
                            StyledText {
                                Layout.fillWidth: true
                                text: row.modelData.appName
                                color: Colors.m3primary
                                font.pixelSize: Appearance.font.size.labelMedium
                            }
                            StyledText {
                                text: Notifications.relativeTime(row.modelData.time)
                                color: Colors.m3outline
                                font.pixelSize: Appearance.font.size.labelMedium
                            }
                        }
                        StyledText {
                            Layout.fillWidth: true
                            text: row.modelData.summary
                            font.weight: Font.Medium
                        }
                        StyledText {
                            Layout.fillWidth: true
                            visible: text !== ""
                            text: row.modelData.body
                            color: Colors.m3onSurfaceVariant
                            font.pixelSize: Appearance.font.size.labelMedium
                            wrapMode: Text.Wrap
                            maximumLineCount: 2
                            elide: Text.ElideRight
                        }
                    }
                }
            }
        }
    }
}
