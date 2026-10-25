import QtQuick
import QtQuick.Controls
import qs.common

// Flickable with animated mouse-wheel scrolling and a thin M3 scrollbar.
// Touchpads (pixel deltas) scroll directly.
Flickable {
    id: root

    property real wheelStep: 120
    property real targetY: 0

    clip: true
    boundsBehavior: Flickable.StopAtBounds
    contentWidth: width

    ScrollBar.vertical: ScrollBar {
        policy: ScrollBar.AsNeeded
        contentItem: Rectangle {
            implicitWidth: 4
            radius: 2
            color: Colors.m3outline
            opacity: parent.active ? 0.8 : 0
            Behavior on opacity { EffectAnim {} }
        }
    }

    WheelHandler {
        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
        onWheel: event => {
            const max = Math.max(0, root.contentHeight - root.height);
            if (event.pixelDelta.y !== 0) {
                scroll.stop();
                root.contentY = Math.max(0, Math.min(max, root.contentY - event.pixelDelta.y));
                return;
            }
            const base = scroll.running ? root.targetY : root.contentY;
            root.targetY = Math.max(0, Math.min(max, base - event.angleDelta.y / 120 * root.wheelStep));
            scroll.restart();
        }
    }

    NumberAnimation {
        id: scroll
        target: root
        property: "contentY"
        to: root.targetY
        duration: Appearance.anim.normal
        easing.type: Easing.OutCubic
    }
}
