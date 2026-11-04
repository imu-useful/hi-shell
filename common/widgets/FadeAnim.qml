import QtQuick
import qs.common

// Opacity change for the content of a morphing pill (the Dynamic Island), used in a Behavior: what goes
// fades out at once; what comes (`incoming`) waits a moment, for the pill to start growing, and fades in.
SequentialAnimation {
    property bool incoming: false

    PauseAnimation { duration: incoming ? Appearance.anim.fast * 0.7 : 0 }
    NumberAnimation {
        duration: incoming ? Appearance.anim.normal : Appearance.anim.fast * 0.6
        easing.type: Easing.BezierSpline
        easing.bezierCurve: Appearance.anim.effects
    }
}
