import QtQuick
import qs.common
import qs.common.widgets
import qs.services

// Active keyboard layout ("EN", "RU"); click = next layout.
BarWidget {
    id: root

    shown: HyprlandXkb.layout !== ""
    clickable: true
    padding: 8
    contentWidth: label.implicitWidth
    contentHeight: label.implicitHeight
    onClicked: HyprlandXkb.next()

    StyledText {
        id: label
        anchors.centerIn: parent
        text: HyprlandXkb.code
        font.pixelSize: Appearance.font.size.labelMedium + 1
        font.weight: Font.DemiBold
    }
}
