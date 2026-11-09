import QtQuick
import qs.common

// The sheen of a pane of glass in the Liquid Glass design: a light wash from the top edge fading
// out, and a faint glow along the bottom. Goes first inside a rounded panel (below its content).
Rectangle {
    anchors.fill: parent
    radius: parent.radius
    visible: Appearance.glass && Appearance.edge > 0
    z: -1
    gradient: Gradient {
        GradientStop { position: 0.0; color: Qt.rgba(1, 1, 1, Colors.dark ? 0.16 : 0.45) }
        GradientStop { position: 0.3; color: Qt.rgba(1, 1, 1, Colors.dark ? 0.04 : 0.12) }
        GradientStop { position: 0.8; color: Qt.rgba(1, 1, 1, 0.0) }
        GradientStop { position: 1.0; color: Qt.rgba(1, 1, 1, Colors.dark ? 0.08 : 0.22) }
    }
}
