import QtQuick
import QtQuick.Layouts
import qs.common
import qs.services

// No card: the clock, avatar and password stand in the middle of the blurred wallpaper; around them float the
// resources (top left), the weather, battery and layout (top right), the player (bottom) and the notifications (right).
Item {
    id: root

    required property var lock
    readonly property real scaleFactor: Math.min(1, (lock.screen?.height ?? 1080) / 1080)

    Center {
        anchors.centerIn: parent
        lock: root.lock
        scaleFactor: root.scaleFactor
    }

    Resources {
        z: 5
        anchors.left: parent.left
        anchors.top: parent.top
        anchors.margins: Appearance.space.xxl
    }

    WeatherInfo {
        z: 5
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: Appearance.space.xxl
    }

    Media {
        z: 5
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: Appearance.space.xxl
    }

    NotifDock {
        anchors.right: parent.right
        anchors.rightMargin: Appearance.space.xxl
        anchors.verticalCenter: parent.verticalCenter
        height: Math.min(implicitHeight, parent.height * 0.6)
    }
}
