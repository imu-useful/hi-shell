import QtQuick
import QtQuick.Layouts
import qs.common
import qs.common.widgets
import qs.common.shapes
import qs.services

// Temperature, condition, city and a row of details.
DesktopCard {
    implicitWidth: 380
    implicitHeight: 120
    visible: Weather.ready

    component Stat: Row {
        property string icon
        property string text
        spacing: 4
        MaterialIcon {
            icon: parent.icon
            iconSize: 15
        }
        StyledText {
            text: parent.text
            font.pixelSize: Appearance.font.size.labelMedium
            color: Colors.m3onSurfaceVariant
        }
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 16
        spacing: 8

        RowLayout {
            Layout.fillWidth: true
            spacing: 12

            StyledText {
                text: Weather.temperature
                font.family: Appearance.font.title
                font.pixelSize: 44
                font.weight: Font.Medium
            }
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 0
                StyledText {
                    Layout.fillWidth: true
                    text: Weather.description
                    font.pixelSize: Appearance.font.size.bodyLarge
                }
                StyledText {
                    Layout.fillWidth: true
                    text: Weather.city
                    font.pixelSize: Appearance.font.size.labelMedium
                    color: Colors.m3onSurfaceVariant
                }
            }
            Item {
                implicitWidth: 52
                implicitHeight: 52
                MaterialShape {
                    anchors.fill: parent
                    shape: "sunny"
                    color: Colors.m3primaryContainer
                }
                MaterialIcon {
                    anchors.centerIn: parent
                    icon: Weather.icon
                    fill: 1
                    iconSize: 28
                    color: Colors.m3onPrimaryContainer
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 14
            visible: Weather.ready
            Stat { icon: "humidity_percentage"; text: Weather.ready ? `${Weather.current.humidity}%` : "" }
            Stat { icon: "cloud"; text: Weather.ready ? `${Weather.current.cloudCover}%` : "" }
            Stat { icon: "air"; text: Weather.ready ? `${Weather.current.wind.toFixed(1)} ${Weather.windUnit}` : "" }
            Item { Layout.fillWidth: true }
            Stat { icon: "wb_twilight"; text: Weather.daily.length ? Weather.daily[0].sunrise.slice(11, 16) : "" }
            Stat { icon: "bedtime"; text: Weather.daily.length ? Weather.daily[0].sunset.slice(11, 16) : "" }
        }
    }
}
