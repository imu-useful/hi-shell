import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.common
import qs.common.widgets
import qs.services

// Today's screen time: the total and the apps in the focus, most used first.
DesktopCard {
    id: root

    readonly property var apps: ScreenTime.totals(ScreenTime.today).slice(0, 4)
    readonly property int total: ScreenTime.totals(ScreenTime.today).reduce((sum, a) => sum + a.seconds, 0)
    readonly property int peak: apps.length ? apps[0].seconds : 1

    function duration(seconds) {
        const m = Math.floor(seconds / 60), h = Math.floor(m / 60);
        if (m === 0)
            return Translation.tr("< 1 min");
        return h ? (m % 60 ? Translation.tr("%1 h %2 min").arg(h).arg(m % 60) : Translation.tr("%1 h").arg(h)) : Translation.tr("%1 min").arg(m);
    }

    implicitWidth: 320
    implicitHeight: column.implicitHeight + 32

    ColumnLayout {
        id: column
        anchors.fill: parent
        anchors.margins: 16
        spacing: 8

        RowLayout {
            Layout.fillWidth: true
            StyledText {
                Layout.fillWidth: true
                text: Translation.tr("Screen time")
                font.pixelSize: Appearance.font.size.labelLarge
                color: Colors.m3onSurfaceVariant
            }
            StyledText {
                text: root.duration(root.total)
                font.pixelSize: Appearance.font.size.titleMedium
                font.weight: Font.Medium
            }
        }

        // A line about the total, once there is something to say.
        RowLayout {
            Layout.fillWidth: true
            visible: root.total >= 60
            spacing: 8

            MaterialIcon {
                icon: ScreenTime.verdict(root.total).icon
                iconSize: 20
                color: Colors.m3primary
            }
            StyledText {
                Layout.fillWidth: true
                text: ScreenTime.verdict(root.total).text
                wrapMode: Text.WordWrap
                font.pixelSize: Appearance.font.size.labelMedium
                color: Colors.m3onSurfaceVariant
            }
        }

        Repeater {
            model: root.apps

            ColumnLayout {
                required property var modelData
                Layout.fillWidth: true
                spacing: 2

                RowLayout {
                    Layout.fillWidth: true
                    StyledText {
                        Layout.fillWidth: true
                        text: DesktopEntries.heuristicLookup(modelData.app)?.name ?? modelData.app
                        elide: Text.ElideRight
                        font.pixelSize: Appearance.font.size.labelMedium
                    }
                    StyledText {
                        text: root.duration(modelData.seconds)
                        font.pixelSize: Appearance.font.size.labelMedium
                        color: Colors.m3onSurfaceVariant
                    }
                }
                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: 4
                    radius: 2
                    color: Colors.m3surfaceContainerHighest
                    Rectangle {
                        width: parent.width * modelData.seconds / root.peak
                        height: parent.height
                        radius: 2
                        color: Colors.m3primary
                    }
                }
            }
        }
    }
}
