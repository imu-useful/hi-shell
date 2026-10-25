import QtQuick
import qs.common

// Translucent rounded surface for desktop widgets.
Rectangle {
    property color baseColor: Colors.m3surfaceContainer

    radius: Appearance.rounding.extraLarge
    color: Qt.alpha(baseColor, Config.options.appearance.transparency ? 0.72 : 1)
}
