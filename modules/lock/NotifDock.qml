import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.common
import qs.common.widgets
import qs.services

// On the right: the notifications that came in, newest first, as loose cards (with "Hide notifications" on, only
// how many). Nothing shows while there are none.
ColumnLayout {
    id: root

    readonly property bool hidden: Config.options.lock.hideNotifs
    readonly property int count: Notifications.list.length

    visible: count > 0
    width: 340
    spacing: Appearance.space.sm
    implicitHeight: header.implicitHeight + spacing + Math.min(list.contentHeight, 520)

    Tile {
        id: header
        Layout.alignment: Qt.AlignRight
        implicitWidth: label.implicitWidth + Appearance.space.lg * 2
        implicitHeight: 32
        StyledText {
            id: label
            anchors.centerIn: parent
            text: Translation.trn("%1 notification", "%1 notifications", root.count)
            color: Colors.m3onSurfaceVariant
            font.pixelSize: Appearance.font.size.labelMedium
        }
    }

    ListView {
        id: list
        Layout.fillWidth: true
        Layout.fillHeight: true
        visible: !root.hidden
        clip: true
        spacing: Appearance.space.sm
        interactive: contentHeight > height
        model: ScriptModel {
            values: [...Notifications.list].reverse()
        }

        delegate: Tile {
            id: row
            required property var modelData
            width: ListView.view.width
            height: col.implicitHeight + Appearance.space.md * 2
            radius: Appearance.rounding.largeIncreased

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
