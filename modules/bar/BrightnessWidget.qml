import QtQuick
import qs.common
import qs.common.widgets
import qs.services

// Screen brightness of the bar's screen in percent; scroll to change it. Hidden when it can't be set.
BarWidget {
    id: root

    readonly property QtObject screenBrightness: Brightness.forScreen(bar?.screen ?? null)

    shown: screenBrightness?.available ?? false
    scrollable: shown
    padding: 9
    contentWidth: grid.implicitWidth
    contentHeight: grid.implicitHeight
    onScrolled: steps => screenBrightness.set(screenBrightness.brightness + steps * 0.05)

    Grid {
        id: grid
        anchors.centerIn: parent
        columns: root.vertical ? 1 : 2
        spacing: 4
        verticalItemAlignment: Grid.AlignVCenter
        horizontalItemAlignment: Grid.AlignHCenter

        MaterialIcon { icon: "brightness_medium"; iconSize: 17; color: Colors.m3primary }
        StyledText {
            text: Math.round((root.screenBrightness?.brightness ?? 0) * 100) + "%"
            font.pixelSize: Appearance.font.size.labelMedium + 1
            font.features: { "tnum": 1 }
        }
    }
}
