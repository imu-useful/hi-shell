import QtQuick
import qs.common

// Text with the shell's font and on-surface color.
Text {
    font.family: Appearance.font.main
    font.pixelSize: Appearance.font.size.bodyMedium
    color: Colors.m3onSurface
    verticalAlignment: Text.AlignVCenter
    elide: Text.ElideRight
}
