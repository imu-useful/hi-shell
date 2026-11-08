import QtQuick
import QtQuick.Layouts
import qs.common
import qs.common.widgets
import qs.services

// Top right: small pills for the weather, the battery and the keyboard layout.
RowLayout {
    spacing: Appearance.space.sm

    component Pill: Tile {
        property string icon
        property string text
        implicitWidth: row.implicitWidth + Appearance.space.lg * 2
        implicitHeight: 40
        Row {
            id: row
            anchors.centerIn: parent
            spacing: Appearance.space.sm
            MaterialIcon { anchors.verticalCenter: parent.verticalCenter; icon: parent.parent.icon; iconSize: 20; color: Colors.m3primary }
            StyledText { anchors.verticalCenter: parent.verticalCenter; text: parent.parent.text }
        }
    }

    Pill {
        id: weatherPill
        visible: Weather.ready
        icon: Weather.icon
        text: `${Weather.temperature} · ${Weather.description}`

        HoverHandler {
            id: hover
        }

        Detail {
            id: wd
            anchors.top: parent.bottom
            anchors.topMargin: Appearance.space.sm
            anchors.right: parent.right
            pillHovered: hover.hovered

            readonly property var today: Weather.daily[0] ?? null
            readonly property var c: Weather.current

            StyledText {
                Layout.alignment: Qt.AlignHCenter
                text: Weather.city
                font.weight: Font.Medium
                visible: text !== ""
            }
            DetailRow { label: Translation.tr("Feels like"); value: wd.c ? `${Math.round(wd.c.feelsLike)}${Weather.tempUnit}` : "" }
            DetailRow { label: Translation.tr("High / low"); value: wd.today ? `${Math.round(wd.today.max)}${Weather.tempUnit} / ${Math.round(wd.today.min)}${Weather.tempUnit}` : "" }
            DetailRow { label: Translation.tr("Humidity"); value: wd.c ? `${Math.round(wd.c.humidity)}%` : "" }
            DetailRow { label: Translation.tr("Wind"); value: wd.c ? `${Math.round(wd.c.wind)} ${Weather.windUnit}` : "" }
            DetailRow { label: Translation.tr("Rain chance"); value: wd.today ? `${Math.round(wd.today.precipitation ?? 0)}%` : "" }
            DetailRow { label: Translation.tr("Sunrise · sunset"); value: wd.today ? `${wd.today.sunrise.slice(11, 16)} · ${wd.today.sunset.slice(11, 16)}` : "" }

            Row {
                Layout.alignment: Qt.AlignHCenter
                Layout.topMargin: Appearance.space.xs
                spacing: Appearance.space.lg
                Repeater {
                    model: Weather.hourly.filter((h, i) => i > 0 && i % 3 === 0).slice(0, 4)
                    Column {
                        required property var modelData
                        spacing: 2
                        StyledText { anchors.horizontalCenter: parent.horizontalCenter; text: modelData.time.slice(11, 16); color: Colors.m3onSurfaceVariant; font.pixelSize: Appearance.font.size.labelSmall }
                        MaterialIcon { anchors.horizontalCenter: parent.horizontalCenter; icon: Weather.iconFor(modelData.code, modelData.isDay); iconSize: 22; color: Colors.m3secondary }
                        StyledText { anchors.horizontalCenter: parent.horizontalCenter; text: `${Math.round(modelData.temp)}°`; font.pixelSize: Appearance.font.size.labelMedium }
                    }
                }
            }
        }
    }
    Pill {
        visible: Battery.available
        icon: Battery.icon
        text: `${Battery.percent}%`
    }
    Pill {
        visible: HyprlandXkb.code !== "" && HyprlandXkb.layout !== "error"
        icon: "keyboard"
        text: HyprlandXkb.code
    }
}
