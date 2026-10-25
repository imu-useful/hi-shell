import QtQuick
import QtQuick.Layouts
import qs.common
import qs.common.widgets
import qs.services

// Battery glyph + percentage; hidden on machines without a battery.
BarWidget {
    id: root

    readonly property color levelColor: Battery.critical ? Colors.m3error : Battery.charging ? Colors.m3tertiary : Colors.m3onSurface

    shown: Battery.available
    padding: 8
    contentWidth: grid.implicitWidth
    contentHeight: grid.implicitHeight

    Grid {
        id: grid
        anchors.centerIn: parent
        columns: root.vertical ? 1 : 2
        spacing: 5
        verticalItemAlignment: Grid.AlignVCenter
        horizontalItemAlignment: Grid.AlignHCenter

        // Battery body with fill level and a tip; bolt while charging.
        Item {
            width: 24
            height: 13

            Rectangle {
                id: body
                width: 21
                height: parent.height
                radius: 4
                color: "transparent"
                border.width: 1.5
                border.color: Qt.alpha(root.levelColor, 0.6)

                Rectangle {
                    x: 2.5
                    y: 2.5
                    height: parent.height - 5
                    width: Math.max(2, (parent.width - 5) * Battery.percentage)
                    radius: 2
                    color: root.levelColor
                    Behavior on width { EffectAnim {} }
                }
            }
            Rectangle {
                anchors.left: body.right
                anchors.leftMargin: 1
                anchors.verticalCenter: body.verticalCenter
                width: 2
                height: 5
                radius: 1
                color: Qt.alpha(root.levelColor, 0.6)
            }
            MaterialIcon {
                visible: Battery.charging
                anchors.centerIn: body
                icon: "bolt"
                fill: 1
                iconSize: 13
                color: Colors.m3surface
                style: Text.Outline
                styleColor: Colors.m3tertiary
            }
        }

        StyledText {
            text: root.vertical ? Battery.percent : `${Battery.percent}%`
            font.pixelSize: Appearance.font.size.labelMedium + 1
            font.features: { "tnum": 1 }
            color: Battery.critical ? Colors.m3error : Colors.m3onSurface
        }
    }

    StyledPopup {
        target: root
        hovered: root.hovered
        edge: root.popupEdge

        ColumnLayout {
            spacing: 4

            StyledText {
                text: Translation.tr("Battery %1%").arg(Battery.percent)
                font.pixelSize: Appearance.font.size.titleMedium
                font.weight: Font.Medium
            }
            StyledText {
                text: Battery.full ? Translation.tr("Fully charged") : Battery.charging
                    ? (Battery.timeLeftText ? Translation.tr("Charging · full in %1").arg(Battery.timeLeftText) : Translation.tr("Charging"))
                    : (Battery.timeLeftText ? Translation.tr("On battery · %1 left").arg(Battery.timeLeftText) : Translation.tr("On battery"))
                color: Colors.m3onSurfaceVariant
            }
            StyledText {
                visible: Battery.watts > 0
                text: Translation.tr("%1 W").arg(Battery.watts.toFixed(1))
                font.pixelSize: Appearance.font.size.labelMedium
                color: Colors.m3onSurfaceVariant
            }
            StyledText {
                visible: Battery.health >= 0
                text: Translation.tr("Health %1%").arg(Math.round(Battery.health))
                font.pixelSize: Appearance.font.size.labelMedium
                color: Colors.m3onSurfaceVariant
            }
        }
    }
}
