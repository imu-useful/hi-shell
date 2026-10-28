import QtQuick
import QtQuick.Effects
import qs.common
import qs.services

// The playing track's cover, blurred, as the backdrop of a media card (the first child of the
// card; `radius` is the card's). A scrim over it keeps the text readable. Off with
// appearance.coverBackdrop, in game mode and in power saving.
Item {
    id: root

    property url source
    property real radius: Appearance.rounding.extraLarge
    readonly property bool active: Config.options.appearance.coverBackdrop && source.toString() !== "" && !Toggles.gameMode && !PowerSaver.enabled

    anchors.fill: parent
    visible: active

    Image {
        id: image
        anchors.fill: parent
        visible: false
        asynchronous: true
        fillMode: Image.PreserveAspectCrop
        // A heavy blur needs few pixels.
        sourceSize: Qt.size(96, 96)
        source: root.active ? root.source : ""
    }

    // The card's rounded outline, to clip the blur to.
    Item {
        id: mask
        anchors.fill: parent
        visible: false
        layer.enabled: true
        Rectangle {
            anchors.fill: parent
            radius: root.radius
            color: "black"
        }
    }

    MultiEffect {
        anchors.fill: parent
        source: image
        blurEnabled: true
        blur: 1
        blurMax: 48
        saturation: 0.25
        brightness: -0.12
        maskEnabled: true
        maskSource: mask
        opacity: image.status === Image.Ready ? 1 : 0
        Behavior on opacity { EffectAnim { duration: Appearance.anim.slow } }
    }

    Rectangle {
        anchors.fill: parent
        radius: root.radius
        color: Qt.alpha(Colors.m3surface, 0.5)
    }
}
