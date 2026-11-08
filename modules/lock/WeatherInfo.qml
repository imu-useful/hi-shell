import QtQuick
import QtQuick.Layouts
import qs.common
import qs.common.widgets
import qs.services

// Weather now: the description, the temperature with its icon, today's high and low.
Tile {
    id: root

    implicitHeight: layout.implicitHeight + Appearance.space.xl * 2

    ColumnLayout {
        id: layout
        anchors.centerIn: parent
        width: parent.width - Appearance.space.xl * 2
        spacing: Appearance.space.xs

        StyledText {
            Layout.alignment: Qt.AlignHCenter
            text: Weather.ready ? Weather.description : Translation.tr("No weather")
            color: Colors.m3onSurfaceVariant
            font.pixelSize: Appearance.font.size.bodyLarge
        }

        RowLayout {
            Layout.alignment: Qt.AlignHCenter
            spacing: Appearance.space.md

            StyledText {
                text: Weather.temperature
                color: Colors.m3primary
                font.family: Appearance.font.title
                font.pixelSize: 46
                font.weight: Font.DemiBold
            }
            MaterialIcon {
                icon: Weather.icon
                iconSize: 46
                color: Colors.m3secondary
            }
        }

        StyledText {
            Layout.alignment: Qt.AlignHCenter
            visible: Weather.ready && Weather.daily.length > 0
            text: Translation.tr("High %1 • Low %2")
                .arg(`${Math.round(Weather.daily[0]?.max ?? 0)}${Weather.tempUnit}`)
                .arg(`${Math.round(Weather.daily[0]?.min ?? 0)}${Weather.tempUnit}`)
            color: Colors.m3onSurfaceVariant
        }
    }
}
