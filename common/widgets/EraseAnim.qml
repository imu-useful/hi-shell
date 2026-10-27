import QtQuick
import qs.common

// The erase animation of a list item that isn't in a ListView (its owner removes it when
// this is over): after `delay` the item slides sideways and fades out (target.leave 0 -> 1),
// then its row folds away (target.collapse 1 -> 0). The target draws itself with those two
// properties. With animations off the durations are 0, so it's over at once.
SequentialAnimation {
    id: root

    property QtObject target
    property int delay: 0

    PauseAnimation { duration: root.delay }
    EffectAnim { target: root.target; property: "leave"; to: 1 }
    NumberAnimation {
        target: root.target
        property: "collapse"
        to: 0
        duration: Appearance.anim.fast
        easing.type: Easing.OutCubic
    }
}
