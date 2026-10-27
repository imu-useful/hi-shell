import QtQuick
import qs.common

// A ListView `remove` transition: the item slides sideways and fades out, staggered by its
// position, so clearing a whole list sweeps through it from the top. Use with
// `displaced: Transition { SpatialAnim { properties: "y" } }` to close the gaps.
Transition {
    id: root

    property int stagger: 45

    SequentialAnimation {
        PauseAnimation { duration: Math.max(0, Math.min(ViewTransition.index, 10)) * root.stagger * Appearance.anim.speed }
        ParallelAnimation {
            EffectAnim { property: "opacity"; to: 0 }
            EffectAnim { property: "scale"; to: 0.92 }
            NumberAnimation {
                property: "x"
                to: (ViewTransition.item?.x ?? 0) + 90
                duration: Appearance.anim.normal
                easing.type: Easing.InCubic
            }
        }
    }
}
