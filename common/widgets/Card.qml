import QtQuick
import qs.common

// Rounded surface container (translucent when transparency is on).
Rectangle {
    property color baseColor: Colors.m3surfaceContainer

    radius: Appearance.rounding.extraLarge
    color: Appearance.translucent(baseColor)
}
