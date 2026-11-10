import QtQuick
import QtQuick.Layouts
import qs.common

// Material 3 filled (or tonal) text button with optional leading icon.
Rectangle {
    id: root

    property string text: ""
    property string icon: ""
    property bool tonal: false

    signal clicked

    readonly property color contentColor: tonal ? Colors.m3onSecondaryContainer : Colors.m3onPrimary

    implicitWidth: row.implicitWidth + 40
    implicitHeight: 40
    // Pressing morphs the pill into a rounded square, and it springs back.
    radius: layer.pressed ? Appearance.rounding.medium : Appearance.shape.button
    color: tonal ? Colors.m3secondaryContainer : Colors.m3primary
    opacity: enabled ? 1 : Appearance.state.disabledContent

    Behavior on radius { SpatialAnim {} }
    Behavior on color { ColorAnim {} }

    scale: layer.pressed ? Appearance.pressScale : 1
    Behavior on scale { enabled: Appearance.anim.speed > 0; SpringAnim { overshoot: 1.4 } }

    RowLayout {
        id: row
        anchors.centerIn: parent
        spacing: 8

        Text {
            visible: root.icon !== ""
            text: root.icon
            font.family: Appearance.font.icon
            font.pixelSize: 18
            color: root.contentColor
        }

        Text {
            text: root.text
            font.family: Appearance.font.main
            font.pixelSize: Appearance.font.size.bodyMedium
            font.weight: Font.Medium
            color: root.contentColor
        }
    }

    StateLayer {
        id: layer
        tint: root.contentColor
        onClicked: root.clicked()
    }
}
