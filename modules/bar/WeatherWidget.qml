import QtQuick
import QtQuick.Layouts
import qs.common
import qs.common.widgets
import qs.services

// Current temperature + condition icon; hover for details and the forecast.
BarWidget {
    id: root

    shown: Weather.enabled && (Weather.ready || Weather.loading)
    padding: 8
    contentWidth: vertical ? thickness : row.implicitWidth
    contentHeight: column.implicitHeight
    clickable: true
    onClicked: Weather.refresh()

    function hour(iso) {
        return iso.slice(11, 16);
    }
    function weekday(date) {
        return new Date(date + "T12:00").toLocaleDateString(Qt.locale(), "ddd");
    }

    RowLayout {
        id: row
        visible: !root.vertical
        anchors.centerIn: parent
        spacing: 6

        MaterialIcon {
            icon: Weather.icon
            iconSize: 18
            fill: 1
            color: Colors.m3primary
        }
        StyledText {
            text: Weather.temperature
            font.pixelSize: Appearance.font.size.normal
        }
    }

    ColumnLayout {
        id: column
        visible: root.vertical
        anchors.centerIn: parent
        spacing: 0

        MaterialIcon {
            Layout.alignment: Qt.AlignHCenter
            icon: Weather.icon
            iconSize: 18
            fill: 1
            color: Colors.m3primary
        }
        StyledText {
            Layout.alignment: Qt.AlignHCenter
            text: Weather.ready ? `${Math.round(Weather.current.temp)}°` : "--"
            font.pixelSize: Appearance.font.size.labelMedium
        }
    }

    component Stat: RowLayout {
        property string icon
        property string text
        // Lets the grid columns share the popup width.
        Layout.fillWidth: true
        Layout.preferredWidth: 1
        spacing: 6
        MaterialIcon {
            icon: parent.icon
            iconSize: 16
        }
        StyledText {
            Layout.fillWidth: true
            text: parent.text
            font.pixelSize: Appearance.font.size.labelMedium
            color: Colors.m3onSurfaceVariant
        }
    }

    StyledPopup {
        target: root
        hovered: root.hovered
        edge: root.popupEdge

        ColumnLayout {
            width: 320
            spacing: 14

            // Header: temperature, condition, city, big icon
            RowLayout {
                Layout.fillWidth: true
                spacing: 12

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 0
                    StyledText {
                        Layout.fillWidth: true
                        text: Weather.temperature
                        font.pixelSize: Appearance.font.size.headlineLarge
                        font.weight: Font.Medium
                    }
                    StyledText {
                        Layout.fillWidth: true
                        text: Weather.description
                    }
                    StyledText {
                        text: Weather.city || "Unknown location"
                        font.pixelSize: Appearance.font.size.labelMedium
                        color: Colors.m3onSurfaceVariant
                    }
                }

                Rectangle {
                    implicitWidth: 56
                    implicitHeight: 56
                    radius: 28
                    color: Colors.m3primaryContainer
                    MaterialIcon {
                        anchors.centerIn: parent
                        icon: Weather.icon
                        iconSize: 32
                        fill: 1
                        color: Colors.m3onPrimaryContainer
                    }
                }
            }

            GridLayout {
                Layout.fillWidth: true
                visible: Weather.ready
                columns: 2
                rowSpacing: 6
                columnSpacing: 16

                Stat {
                    icon: "thermostat"
                    text: Weather.ready ? `Feels like ${Math.round(Weather.current.feelsLike)}${Weather.tempUnit}` : ""
                }
                Stat {
                    icon: "humidity_percentage"
                    text: Weather.ready ? `${Weather.current.humidity}%` : ""
                }
                Stat {
                    icon: "air"
                    text: Weather.ready ? `${Weather.current.wind.toFixed(1)} ${Weather.windUnit}` : ""
                }
                Stat {
                    icon: "visibility"
                    text: Weather.ready ? `${(Weather.current.visibility / 1000).toFixed(1)} km` : ""
                }
                Stat {
                    icon: "wb_twilight"
                    text: Weather.daily.length ? root.hour(Weather.daily[0].sunrise) : ""
                }
                Stat {
                    icon: "bedtime"
                    text: Weather.daily.length ? root.hour(Weather.daily[0].sunset) : ""
                }
            }

            // Next hours
            RowLayout {
                Layout.fillWidth: true
                visible: Weather.hourly.length > 0
                spacing: 0

                Repeater {
                    model: Weather.hourly.filter((h, i) => i % 3 === 0).slice(0, 6)

                    ColumnLayout {
                        required property var modelData
                        // A nested layout can't grow past its children's maximum width,
                        // so lift it to get equal columns.
                        Layout.fillWidth: true
                        Layout.preferredWidth: 1
                        Layout.maximumWidth: Number.POSITIVE_INFINITY
                        spacing: 2

                        StyledText {
                            Layout.alignment: Qt.AlignHCenter
                            text: root.hour(modelData.time)
                            font.pixelSize: Appearance.font.size.labelSmall
                            color: Colors.m3onSurfaceVariant
                        }
                        MaterialIcon {
                            Layout.alignment: Qt.AlignHCenter
                            icon: Weather.iconFor(modelData.code, modelData.isDay)
                            iconSize: 20
                            color: Colors.m3onSurface
                        }
                        StyledText {
                            Layout.alignment: Qt.AlignHCenter
                            text: `${Math.round(modelData.temp)}°`
                            font.pixelSize: Appearance.font.size.labelMedium
                        }
                    }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                implicitHeight: 1
                color: Colors.m3outlineVariant
            }

            // Daily forecast
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 6

                Repeater {
                    model: Weather.daily.slice(0, 5)

                    RowLayout {
                        required property var modelData
                        required property int index
                        Layout.fillWidth: true
                        spacing: 10

                        StyledText {
                            Layout.preferredWidth: 48
                            text: index === 0 ? "Today" : root.weekday(modelData.date)
                            font.pixelSize: Appearance.font.size.labelMedium + 1
                        }
                        MaterialIcon {
                            icon: Weather.iconFor(modelData.code, true)
                            iconSize: 18
                        }
                        StyledText {
                            Layout.fillWidth: true
                            text: modelData.precipitation > 0 ? `${modelData.precipitation}%` : ""
                            font.pixelSize: Appearance.font.size.labelSmall
                            color: Colors.m3primary
                        }
                        StyledText {
                            text: `${Math.round(modelData.min)}° / ${Math.round(modelData.max)}°`
                            font.pixelSize: Appearance.font.size.labelMedium + 1
                            font.features: { "tnum": 1 }
                        }
                    }
                }
            }

            StyledText {
                visible: Weather.error !== ""
                Layout.fillWidth: true
                text: Weather.error
                font.pixelSize: Appearance.font.size.labelSmall
                color: Colors.m3error
                wrapMode: Text.Wrap
            }
        }
    }
}
