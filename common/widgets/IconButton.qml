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
    radius: Appearance.rounding.full
    color: filled ? (mouse.containsMouse ? Qt.lighter(Colors.m3primary, 1.08) : Colors.m3primary)
                  : (mouse.containsMouse ? Colors.m3surfaceContainerHighest : "transparent")
    opacity: enabled ? 1 : 0.38

    Behavior on color { ColorAnimation { duration: 120 } }

    // Pressing squeezes the button a little and it springs back.
    scale: mouse.pressed ? 0.9 : 1
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

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }
}
