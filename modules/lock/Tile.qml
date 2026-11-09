import QtQuick
import qs.common
import qs.common.widgets

// A soft tonal pill or block floating over the lock's wallpaper.
Rectangle {
    radius: Appearance.rounding.full
    color: Appearance.translucent(Colors.m3surfaceContainer, 0.25)
    border.width: Appearance.edge
    border.color: Appearance.edgeColor

    GlassSheen {}
}
