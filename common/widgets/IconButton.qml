import QtQuick
import qs.common

// Square icon button using Material Symbols: standard (bare, outlined on hover) or filled in the accent.
Rectangle {
    id: root

    property string icon: ""
    property bool filled: false
    property color iconColor: filled ? Colors.m3onPrimary : layer.containsMouse ? Colors.m3primary : Colors.m3onSurfaceVariant
    property string tooltip: ""

    signal clicked

    implicitWidth: 36
    implicitHeight: 36
    radius: Appearance.shape.button
    color: filled ? Colors.m3primary : "transparent"
    border.width: filled ? 0 : Appearance.edge
    border.color: layer.containsMouse ? Colors.m3outline : "transparent"
    opacity: enabled ? 1 : Appearance.state.disabledContent

    Behavior on color { ColorAnim {} }
    Behavior on border.color { ColorAnim {} }

    scale: layer.pressed ? Appearance.anim.pressScale : 1
    Behavior on scale { enabled: Appearance.anim.speed > 0; SpringAnim { overshoot: 1.4 } }

    Text {
        id: glyph
        anchors.centerIn: parent
        text: root.icon
        font.family: Appearance.font.icon
        font.pixelSize: 20
        color: root.iconColor
        Behavior on color { ColorAnimation { duration: 120 } }

        // A changed icon (play/pause) flicks in instead of snapping.
        onTextChanged: if (Appearance.anim.speed > 0) swap.restart()
        NumberAnimation {
            id: swap
            target: glyph
            property: "opacity"
            from: 0
            to: 1
            duration: Appearance.anim.fast
        }
    }

    StateLayer {
        id: layer
        tint: root.filled ? Colors.m3onPrimary : Colors.m3primary
        onClicked: root.clicked()
    }
}
