import QtQuick
import qs.common

// Position / size animation with the M3 Expressive spatial (springy) curve.
NumberAnimation {
    // A category's own factor (appearance.panelSpeed, barSpeed, notificationSpeed) on top of the global speed.
    property real speed: 1

    duration: Appearance.anim.spatial * speed
    easing.type: Easing.BezierSpline
    easing.bezierCurve: Appearance.anim.spatialDefault
}
