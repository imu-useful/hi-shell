import QtQuick
import QtQuick.Layouts
import qs.common
import qs.common.widgets
import qs.services

// Pending updates count; click opens a terminal with the upgrade.
BarWidget {
    id: root

    shown: Config.options.updates.enabled && (Updates.count > 0 || !Config.options.bar.updates.hideWhenNone)
    clickable: true
    padding: 8
    contentWidth: grid.implicitWidth
    contentHeight: grid.implicitHeight
    onClicked: Updates.run()

    Grid {
        id: grid
        anchors.centerIn: parent
        columns: root.vertical ? 1 : 2
        spacing: 4
        verticalItemAlignment: Grid.AlignVCenter
        horizontalItemAlignment: Grid.AlignHCenter

        MaterialIcon {
            icon: Updates.checking ? "sync" : "system_update_alt"
            iconSize: 17
            color: Colors.m3primary
        }
        StyledText {
            text: Updates.count
            font.pixelSize: Appearance.font.size.labelMedium + 1
        }
    }

    StyledPopup {
        target: root
        hovered: root.hovered
        edge: root.popupEdge

        ColumnLayout {
            spacing: 4

            StyledText {
                text: Translation.trn("%1 update", "%1 updates", Updates.count)
                font.pixelSize: Appearance.font.size.titleMedium
                font.weight: Font.Medium
            }
            Repeater {
                model: Updates.packages.slice(0, 15)

                StyledText {
                    required property var modelData
                    text: `${modelData.name}  ${modelData.from} → ${modelData.to}${modelData.aur ? Translation.tr("  (AUR)") : ""}`
                    font.pixelSize: Appearance.font.size.labelMedium
                    font.family: Appearance.font.mono
                    color: Colors.m3onSurfaceVariant
                }
            }
            StyledText {
                visible: Updates.count > 15
                text: Translation.tr("and %1 more").arg(Updates.count - 15)
                font.pixelSize: Appearance.font.size.labelMedium
                color: Colors.m3outline
            }
            StyledText {
                text: Translation.tr("Click to upgrade")
                font.pixelSize: Appearance.font.size.labelSmall
                color: Colors.m3primary
            }
        }
    }
}
