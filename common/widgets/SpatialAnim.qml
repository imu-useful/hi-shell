import QtQuick
import qs.common

// Position / size animation with the M3 Expressive spatial (springy) curve.
NumberAnimation {
    duration: Appearance.anim.spatial
    easing.type: Easing.BezierSpline
    easing.bezierCurve: Appearance.anim.spatialDefault
}
