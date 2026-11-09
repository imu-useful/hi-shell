import QtQuick
import qs.common
import qs.common.widgets

// Key "hi": "Hi to you too" over the animated logo.
Column {
    id: root

    required property bool revealed
    required property real screenWidth
    required property real screenHeight

    spacing: 32

    StyledText {
        id: greeting
        anchors.horizontalCenter: parent.horizontalCenter
        text: Translation.tr("Hi to you too")
        font.family: Appearance.font.title
        font.pixelSize: Math.min(96, root.screenWidth / 12)
        font.weight: Font.DemiBold
        color: "white"
        elide: Text.ElideNone
        property real rise: root.revealed ? 1 : 0
        opacity: rise
        transform: Translate { y: (1 - greeting.rise) * 24 }
        Behavior on rise { NumberAnimation { duration: 700; easing.type: Easing.OutCubic } }
    }

    AnimatedLogo {
        anchors.horizontalCenter: parent.horizontalCenter
        height: Math.min(320, root.screenHeight * 0.4)
        playing: root.revealed
    }
}
