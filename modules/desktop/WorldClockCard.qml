import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.common
import qs.common.widgets
import qs.services

// Local time and date plus the zones in Config desktop.worldClocks.
DesktopCard {
    implicitWidth: 340
    implicitHeight: content.implicitHeight + 28

    SystemClock {
        id: clock
        precision: SystemClock.Minutes
    }

    ColumnLayout {
        id: content
        anchors.fill: parent
        anchors.margins: 14
        spacing: 8

        RowLayout {
            MaterialIcon {
                icon: "location_on"
                iconSize: 18
            }
            StyledText {
                Layout.fillWidth: true
                text: Weather.city || "Local time"
                color: Colors.m3onSurfaceVariant
            }
        }
        StyledText {
            text: Qt.formatTime(clock.date, "HH:mm")
            font.family: Appearance.font.title
            font.pixelSize: 48
            font.weight: Font.Bold
        }
        StyledText {
            text: Qt.formatDate(clock.date, "dddd, d MMMM yyyy")
            font.pixelSize: Appearance.font.size.labelMedium
            color: Colors.m3onSurfaceVariant
        }

        GridLayout {
            Layout.fillWidth: true
            columns: 2
            columnSpacing: 8
            rowSpacing: 8

            Repeater {
                model: WorldClock.clocks

                Rectangle {
                    required property var modelData
                    Layout.fillWidth: true
                    Layout.preferredWidth: 1
                    implicitHeight: 58
                    radius: Appearance.rounding.large
                    color: Colors.m3surfaceContainerHighest

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 10
                        spacing: 0
                        RowLayout {
                            StyledText {
                                Layout.fillWidth: true
                                text: modelData.city
                                font.pixelSize: Appearance.font.size.labelSmall
                                color: Colors.m3onSurfaceVariant
                            }
                            StyledText {
                                text: modelData.offset
                                font.pixelSize: Appearance.font.size.labelSmall
                                color: Colors.m3outline
                            }
                        }
                        RowLayout {
                            StyledText {
                                Layout.fillWidth: true
                                text: modelData.time
                                font.pixelSize: Appearance.font.size.titleMedium
                                font.weight: Font.DemiBold
                            }
                            MaterialIcon {
                                icon: modelData.isDay ? "light_mode" : "dark_mode"
                                iconSize: 16
                            }
                        }
                    }
                }
            }
        }
    }
}
