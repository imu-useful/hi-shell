import QtQuick
import qs.common

// Opacity / scale animation with the M3 effects curve (no overshoot).
NumberAnimation {
    duration: Appearance.anim.normal
    easing.type: Easing.BezierSpline
    easing.bezierCurve: Appearance.anim.effects
}
