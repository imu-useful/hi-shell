import QtQuick
import QtQuick.Layouts
import qs.common
import qs.common.widgets
import qs.services

// Download / upload rate; hover for totals since boot.
BarWidget {
    id: root

    padding: 10
    contentWidth: grid.implicitWidth
    contentHeight: grid.implicitHeight

    function bytes(b) {
        return NetworkSpeed.format(b).replace("/s", "");
    }

    Grid {
        id: grid
        anchors.centerIn: parent
        columns: root.vertical ? 1 : 4
        spacing: 2
        verticalItemAlignment: Grid.AlignVCenter
        horizontalItemAlignment: Grid.AlignHCenter

        MaterialIcon { icon: "arrow_downward"; iconSize: 14; color: Colors.m3primary }
        StyledText {
            rightPadding: root.vertical ? 0 : 6
            text: NetworkSpeed.format(NetworkSpeed.download)
            font.pixelSize: Appearance.font.size.labelMedium
            font.features: { "tnum": 1 }
        }
        MaterialIcon { icon: "arrow_upward"; iconSize: 14; color: Colors.m3tertiary }
        StyledText {
            text: NetworkSpeed.format(NetworkSpeed.upload)
            font.pixelSize: Appearance.font.size.labelMedium
            font.features: { "tnum": 1 }
        }
    }

    StyledPopup {
        target: root
        hovered: root.hovered
        edge: root.popupEdge

        ColumnLayout {
            spacing: 6
            StyledText {
                text: Translation.tr("Network")
                font.weight: Font.Medium
            }
            StyledText {
                text: Translation.tr("Downloaded %1 · Uploaded %2").arg(root.bytes(NetworkSpeed.totalDownload)).arg(root.bytes(NetworkSpeed.totalUpload))
                font.pixelSize: Appearance.font.size.labelMedium
                color: Colors.m3onSurfaceVariant
            }
        }
    }
}
