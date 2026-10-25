import QtQuick
import qs.common

// Material Symbols glyph; `fill` 0..1 animates between outlined and filled.
Text {
    id: root

    property string icon: ""
    property real iconSize: 22
    property real fill: 0

    text: icon
    font.family: Appearance.font.icon
    font.pixelSize: iconSize
    font.variableAxes: ({ "FILL": fill, "opsz": Math.max(20, Math.min(48, iconSize)) })
    color: Colors.m3onSurfaceVariant
    // Filled glyphs have overlapping contours that distance-field text renders with artifacts.
    renderType: fill > 0 ? Text.CurveRendering : Text.QtRendering
    verticalAlignment: Text.AlignVCenter
    horizontalAlignment: Text.AlignHCenter

    Behavior on fill { EffectAnim {} }
}
