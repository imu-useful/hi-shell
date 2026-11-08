import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Wayland
import qs.common
import qs.common.widgets
import qs.services

// One screen of the lock: the wallpaper blurred and dimmed, and the card (Content) in the middle.
// The card grows in when the lock starts and fades out before the session is let go.
WlSessionLockSurface {
    id: root

    required property WlSessionLock lock
    required property var pam

    readonly property alias unlocking: unlockAnim.running
    readonly property real cardHeight: Math.min(760, (screen?.height ?? 900) * 0.72)
    readonly property real cardWidth: Math.min(cardHeight * 16 / 9, (screen?.width ?? 1600) - 64)

    color: Colors.m3surface

    Connections {
        target: root.lock
        function onUnlock() {
            unlockAnim.start();
        }
    }

    SequentialAnimation {
        id: unlockAnim

        ParallelAnimation {
            NumberAnimation { target: card; property: "scale"; to: 0.92; duration: Appearance.anim.normal; easing.type: Easing.BezierSpline; easing.bezierCurve: Appearance.anim.emphasizedAccel }
            NumberAnimation { target: card; property: "opacity"; to: 0; duration: Appearance.anim.normal; easing.type: Easing.BezierSpline; easing.bezierCurve: Appearance.anim.emphasizedAccel }
            NumberAnimation { target: backdrop; property: "opacity"; to: 0; duration: Appearance.anim.slow; easing.type: Easing.BezierSpline; easing.bezierCurve: Appearance.anim.effects }
        }
        PropertyAction { target: root.lock; property: "locked"; value: false }
    }

    ParallelAnimation {
        running: true
        NumberAnimation { target: backdrop; property: "opacity"; to: 1; duration: Appearance.anim.slow; easing.type: Easing.BezierSpline; easing.bezierCurve: Appearance.anim.effects }
        NumberAnimation { target: card; property: "scale"; to: 1; duration: Appearance.anim.spatial; easing.type: Easing.BezierSpline; easing.bezierCurve: Appearance.anim.spatialDefault }
        NumberAnimation { target: card; property: "opacity"; to: 1; duration: Appearance.anim.normal; easing.type: Easing.BezierSpline; easing.bezierCurve: Appearance.anim.effects }
    }

    Item {
        id: backdrop
        anchors.fill: parent
        opacity: 0

        Image {
            id: wallpaper
            anchors.fill: parent
            visible: false
            asynchronous: true
            fillMode: Image.PreserveAspectCrop
            source: Config.options.lock.wallpaper && Wallpapers.still !== "" ? `file://${Wallpapers.still}` : ""
            sourceSize: Qt.size(root.screen?.width ?? 1920, root.screen?.height ?? 1080)
        }

        MultiEffect {
            anchors.fill: parent
            source: wallpaper
            visible: wallpaper.status === Image.Ready
            blurEnabled: true
            blur: 1
            blurMax: 64
            brightness: -(1 - Config.options.lock.brightness) * 0.35
        }
    }

    Rectangle {
        id: card

        anchors.centerIn: parent
        width: root.cardWidth
        height: root.cardHeight
        radius: Appearance.rounding.extraLargeIncreased
        color: Appearance.translucent(Colors.m3surface)
        border.width: Appearance.edge
        border.color: Colors.m3outlineVariant
        opacity: 0
        scale: 0.85

        layer.enabled: true
        layer.effect: MultiEffect {
            shadowEnabled: true
            shadowBlur: 1
            shadowColor: Qt.alpha("black", 0.5)
        }

        Content {
            anchors.fill: parent
            anchors.margins: Appearance.space.xl
            lock: root
        }
    }
}
