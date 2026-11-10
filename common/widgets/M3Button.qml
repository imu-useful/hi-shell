import QtQuick
import QtQuick.Layouts
import qs.common

// Text button with optional leading icon: filled in the accent, or (`tonal`) an outlined one.
// The label is set in uppercase, tracked out.
Rectangle {
    id: root

    property string text: ""
    property string icon: ""
    property bool tonal: false

    signal clicked

    readonly property color contentColor: tonal ? (layer.containsMouse ? Colors.m3primary : Colors.m3onSurface) : Colors.m3onPrimary

    implicitWidth: row.implicitWidth + 28
    implicitHeight: 34
    radius: Appearance.shape.button
    color: tonal ? "transparent" : Colors.m3primary
    border.width: tonal ? Appearance.edge : 0
    border.color: layer.containsMouse ? Colors.m3primary : Colors.m3outline
    opacity: enabled ? 1 : Appearance.state.disabledContent

    Behavior on color { ColorAnim {} }
    Behavior on border.color { ColorAnim {} }

    scale: layer.pressed ? Appearance.anim.pressScale : 1
    Behavior on scale { enabled: Appearance.anim.speed > 0; SpringAnim { overshoot: 1.4 } }

    RowLayout {
        id: row
        anchors.centerIn: parent
        spacing: 8

        Text {
            visible: root.icon !== ""
            text: root.icon
            font.family: Appearance.font.icon
            font.pixelSize: 17
            color: root.contentColor
        }

        Text {
            text: root.text
            font.family: Appearance.font.main
            font.pixelSize: Appearance.font.size.labelMedium
            font.weight: Font.DemiBold
            font.letterSpacing: Appearance.font.labelSpacing * 0.6
            font.capitalization: Font.AllUppercase
            color: root.contentColor
        }
    }

    StateLayer {
        id: layer
        tint: root.tonal ? Colors.m3primary : Colors.m3onPrimary
        onClicked: root.clicked()
    }
}
