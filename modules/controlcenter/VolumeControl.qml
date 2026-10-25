import QtQuick
import QtQuick.Layouts
import Quickshell.Services.Pipewire
import qs.common

// Default output volume via PipeWire.
RowLayout {
    id: root

    readonly property PwNode sink: Pipewire.defaultAudioSink
    readonly property bool ready: sink !== null && sink.audio !== null
    readonly property bool muted: ready && sink.audio.muted
    readonly property real volume: ready ? sink.audio.volume : 0

    spacing: 12

    // Audio properties are only populated for tracked nodes.
    PwObjectTracker {
        objects: [root.sink]
    }

    IconButton {
        icon: root.muted || root.volume === 0 ? "volume_off" : root.volume < 0.5 ? "volume_down" : "volume_up"
        enabled: root.ready
        onClicked: root.sink.audio.muted = !root.sink.audio.muted
    }

    M3Slider {
        Layout.fillWidth: true
        enabled: root.ready
        opacity: root.muted ? 0.5 : 1
        value: root.volume
        onMoved: v => {
            root.sink.audio.volume = v;
            if (root.sink.audio.muted)
                root.sink.audio.muted = false;
        }
    }

    Text {
        Layout.preferredWidth: 40
        horizontalAlignment: Text.AlignRight
        text: root.ready ? Math.round(root.volume * 100) + "%" : "—"
        font.family: Style.fontFamily
        font.pixelSize: 13
        color: Colors.m3onSurfaceVariant
    }
}
