import QtQuick
import qs.common

// Bouncy panel motion: goes past the target and settles back, like a spring.
// For panels and popups appearing (scale, slide); `overshoot` sets how far past
// the target it goes (Easing.OutBack's amplitude; ~1.7 for scale, less for long slides).
NumberAnimation {
    property real overshoot: 1.7

    duration: Appearance.anim.spatial
    easing.type: Easing.OutBack
    easing.overshoot: overshoot
}
