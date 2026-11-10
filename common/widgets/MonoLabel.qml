import QtQuick
import qs.common

// A small UPPERCASE label in monospace, tracked out: section names, units, keys ("WIFI", "VOL", "// NOTIFICATIONS").
StyledText {
    font.family: Appearance.font.mono
    font.pixelSize: Appearance.font.size.labelSmall
    font.weight: Font.Medium
    font.letterSpacing: Appearance.font.labelSpacing
    font.capitalization: Font.AllUppercase
    color: Colors.m3onSurfaceVariant
}
