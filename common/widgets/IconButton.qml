import QtQuick
import qs.common

// Material 3 icon button (standard or filled) using Material Symbols.
Rectangle {
    id: root

    property string icon: ""
    property bool filled: false
    property color iconColor: filled ? Colors.m3onPrimary : Colors.m3onSurfaceVariant
    property string tooltip: ""

    signal clicked

    implicitWidth: 40
    implicitHeight: 40
    // Pressing morphs the circle into a rounded square, and it springs back.
    radius: layer.pressed ? Appearance.rounding.medium : Appearance.shape.button
    color: filled ? Colors.m3primary : "transparent"
    opacity: enabled ? 1 : Appearance.state.disabledContent

    Behavior on radius { SpatialAnim {} }
    Behavior on color { ColorAnim {} }

    // Pressing squeezes the button a little and it springs back.
    scale: layer.pressed ? Appearance.anim.pressScale : 1
    Behavior on scale { enabled: Appearance.anim.speed > 0; SpringAnim { overshoot: 1.4 } }

    Text {
        id: glyph
        anchors.centerIn: parent
        text: root.icon
        font.family: Appearance.font.icon
        font.pixelSize: 22
        color: root.iconColor
        Behavior on color { ColorAnimation { duration: 120 } }

        // A changed icon (play/pause) shrinks in instead of snapping.
        onTextChanged: if (Appearance.anim.speed > 0) swap.restart()
        NumberAnimation {
            id: swap
            target: glyph
            property: "scale"
            from: 0.5
            to: 1
            duration: Appearance.anim.normal
            easing.type: Easing.OutBack
        }
    }

    StateLayer {
        id: layer
        tint: root.iconColor
        onClicked: root.clicked()
    }
}
