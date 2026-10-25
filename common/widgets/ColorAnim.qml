import QtQuick
import qs.common

ColorAnimation {
    duration: Appearance.anim.fast
    easing.type: Easing.BezierSpline
    easing.bezierCurve: Appearance.anim.effects
}
