import QtQuick
import QtMultimedia
import qs.common
import qs.common.widgets
import qs.services

// A video or an animated picture (gif) as the wallpaper, drawn over the still one: it fades in
// once the first frame is there, so a slow start shows the still instead of a blank. `playing`
// off (a window covers the desktop, power saving) pauses it on the frame it's at. No sound.
Item {
    id: root

    // The file to play ("" = nothing live); a video or a gif by its extension.
    property string source: ""
    readonly property string kind: Wallpapers.kindOf(source)
    property bool playing: true
    // The picture to take frames from (for the frame shape).
    readonly property Item output: kind === "video" ? videoLoader.item?.output ?? null : gifLoader.item
    readonly property bool ready: kind === "video" ? videoLoader.item?.ready ?? false : gifLoader.item?.status === AnimatedImage.Ready

    opacity: ready ? 1 : 0
    visible: opacity > 0
    Behavior on opacity { EffectAnim { duration: Appearance.anim.slow * 2 } }

    Loader {
        id: videoLoader
        anchors.fill: parent
        active: root.kind === "video" && root.source !== ""
        sourceComponent: Item {
            readonly property alias output: out
            readonly property bool ready: player.hasVideo && (player.playbackState !== MediaPlayer.StoppedState)

            MediaPlayer {
                id: player
                source: `file://${root.source}`
                videoOutput: out
                loops: MediaPlayer.Infinite
                // Started or paused as soon as it's loaded; a paused one still shows its first frame.
                onMediaStatusChanged: if (mediaStatus === MediaPlayer.LoadedMedia) root.playing ? play() : pause()
                onErrorOccurred: (error, text) => console.warn("LiveWallpaper:", text)
            }
            VideoOutput {
                id: out
                anchors.fill: parent
                fillMode: VideoOutput.PreserveAspectCrop
            }
            Connections {
                target: root
                function onPlayingChanged() {
                    if (player.mediaStatus !== MediaPlayer.LoadedMedia && player.mediaStatus !== MediaPlayer.BufferedMedia
                        && player.mediaStatus !== MediaPlayer.EndOfMedia)
                        return;
                    if (root.playing)
                        player.play();
                    else
                        player.pause();
                }
            }
        }
    }

    Loader {
        id: gifLoader
        anchors.fill: parent
        active: root.kind === "gif" && root.source !== ""
        sourceComponent: AnimatedImage {
            source: `file://${root.source}`
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            cache: false
            playing: root.playing
        }
    }
}
