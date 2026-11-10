import QtQuick
import qs.common

// Surface container: a dark fill (translucent when transparency is on) inside a hairline outline.
Rectangle {
    property color baseColor: Colors.m3surfaceContainer

    radius: Appearance.shape.panel
    color: Appearance.translucent(baseColor)
    border.width: Appearance.edge
    border.color: Colors.m3outlineVariant
}
