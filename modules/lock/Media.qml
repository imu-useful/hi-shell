import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.common
import qs.common.widgets
import qs.services

// The player: the cover behind the title and artist, previous / play / next.
Tile {
    id: root

    clip: true
    radius: Appearance.rounding.extraLarge
    implicitHeight: layout.implicitHeight + Appearance.space.xl * 2

    Image {
        anchors.fill: parent
        source: Mpris.artUrl
        asynchronous: true
        fillMode: Image.PreserveAspectCrop
        sourceSize: Qt.size(width, height)
        opacity: status === Image.Ready ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: Appearance.anim.slow } }

        Rectangle {
            anchors.fill: parent
            color: Colors.m3surface
            opacity: 0.7
        }
    }

    ColumnLayout {
        id: layout
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        anchors.margins: Appearance.space.xl
        spacing: Appearance.space.xs

        StyledText {
            Layout.fillWidth: true
            text: Mpris.hasPlayer ? Mpris.title : Translation.tr("Nothing playing")
            color: Colors.m3primary
            horizontalAlignment: Text.AlignHCenter
            font.pixelSize: Appearance.font.size.titleMedium
            font.weight: Font.Medium
        }

        StyledText {
            Layout.fillWidth: true
            text: Mpris.hasPlayer ? Mpris.artist : Translation.tr("Try playing some music!")
            color: Colors.m3onSurfaceVariant
            horizontalAlignment: Text.AlignHCenter
        }

        Row {
            Layout.alignment: Qt.AlignHCenter
            Layout.topMargin: Appearance.space.md
            spacing: Appearance.space.xs

            IconButton {
                icon: "skip_previous"
                enabled: Mpris.active?.canGoPrevious ?? false
                onClicked: Mpris.previous()
            }
            IconButton {
                icon: Mpris.playing ? "pause" : "play_arrow"
                filled: true
                enabled: Mpris.active?.canTogglePlaying ?? false
                implicitWidth: 64
                onClicked: Mpris.togglePlaying()
            }
            IconButton {
                icon: "skip_next"
                enabled: Mpris.active?.canGoNext ?? false
                onClicked: Mpris.next()
            }
        }
    }
}
