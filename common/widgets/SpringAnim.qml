import QtQuick
import qs.common

// Bouncy panel motion: goes past the target and settles back, like a spring.
// For panels and popups appearing (scale, slide); `overshoot` sets how far past
// the target it goes (Easing.OutBack's amplitude; ~1.7 for scale, less for long slides).
NumberAnimation {
    // The spring slider (appearance.animationBounce) scales the overshoot; `speed` is a category's own factor.
    property real overshoot: 1.7
    property real speed: 1

    duration: Appearance.anim.spatial * speed
    easing.type: Easing.OutBack
    easing.overshoot: overshoot * Appearance.anim.bounce
}
