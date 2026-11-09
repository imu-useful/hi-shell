import QtQuick
import QtMultimedia
import Quickshell

// Keys "man" and "egg": the video, looped, fitted to the screen, with its own music.
Item {
    id: root

    required property bool revealed

    MusicLoop { file: "Man_music.ogx"; playing: root.revealed }

    MediaPlayer {
        id: player
        source: Qt.resolvedUrl("drune.mp4")
        videoOutput: output
        loops: MediaPlayer.Infinite
        Component.onCompleted: play()
    }

    VideoOutput {
        id: output
        anchors.fill: parent
        fillMode: VideoOutput.PreserveAspectFit
    }
}
