import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Wayland
import qs.common
import qs.common.widgets
import qs.services

// One screen of the lock: the wallpaper blurred and dimmed, and the floating content (Content) over it.
// The content eases in when the lock starts and fades out before the session is let go.
WlSessionLockSurface {
    id: root

    required property WlSessionLock lock
    required property var pam

    readonly property alias unlocking: unlockAnim.running

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
            NumberAnimation { target: card; property: "scale"; to: 1.03; duration: Appearance.anim.normal; easing.type: Easing.BezierSpline; easing.bezierCurve: Appearance.anim.emphasizedAccel }
            NumberAnimation { target: card; property: "opacity"; to: 0; duration: Appearance.anim.normal; easing.type: Easing.BezierSpline; easing.bezierCurve: Appearance.anim.emphasizedAccel }
            NumberAnimation { target: backdrop; property: "opacity"; to: 0; duration: Appearance.anim.slow; easing.type: Easing.BezierSpline; easing.bezierCurve: Appearance.anim.effects }
        }
        PropertyAction { target: root.lock; property: "locked"; value: false }
        // lockedChanged doesn't always reach the shell's own flag.
        ScriptAction { script: ShellState.locked = false }
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

    Item {
        id: card

        anchors.fill: parent
        opacity: 0
        scale: 0.96

        Content {
            anchors.fill: parent
            lock: root
        }
    }
}
