import QtQuick
import QtQuick.Layouts
import qs.common
import qs.common.widgets
import qs.services

// The island's volume / brightness / microphone / keyboard layout view (Island.osd): the icon, a level
// bar that fills smoothly and the text.
RowLayout {
    id: root

    property bool compact: false

    spacing: 8

    MaterialIcon {
        icon: Island.osd.icon
        fill: 1
        iconSize: 18
    }
    Rectangle {
        visible: Island.osd.value >= 0 && !root.compact
        implicitWidth: 80
        implicitHeight: 6
        radius: 3
        color: Colors.m3secondaryContainer

        Rectangle {
            width: parent.width * Math.max(0, Math.min(1, Island.osd.value))
            height: parent.height
            radius: 3
            color: Colors.m3primary
            Behavior on width { EffectAnim { duration: Appearance.anim.normal } }
        }
    }
    StyledText {
        visible: !root.compact
        text: Island.osd.label
        font.pixelSize: Appearance.font.size.normal
        font.weight: Font.Medium
        font.family: Appearance.font.mono
        font.features: { "tnum": 1 }
    }
}
