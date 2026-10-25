import QtQuick
import Quickshell
import Quickshell.Io
import qs.common
import qs.common.widgets
import qs.services

// Mini audio spectrum from cava; only runs while media is playing.
BarWidget {
    id: root

    readonly property int bars: 10
    property list<real> levels: []

    shown: Mpris.playing
    padding: 10
    contentWidth: bars * 4 - 1
    contentHeight: bars * 4 - 1

    // cava reads its config from a file; raw ASCII output, one frame per line ("12;40;7;...").
    readonly property string config: `[general]\nbars = ${bars}\nframerate = 30\n[input]\nmethod = pipewire\n[output]\nmethod = raw\nraw_target = /dev/stdout\ndata_format = ascii\nascii_max_range = 100\nbar_delimiter = 59\n`

    Process {
        running: root.visible && Appearance.anim.speed > 0
        command: ["sh", "-c", `cfg=$(mktemp); printf '%b' "$1" > "$cfg"; exec cava -p "$cfg"`, "sh", root.config]
        stdout: SplitParser {
            onRead: line => root.levels = line.split(";").filter(v => v !== "").map(v => Number(v) / 100)
        }
        onRunningChanged: if (!running) root.levels = []
    }

    Repeater {
        model: root.bars

        Rectangle {
            required property int index
            readonly property real level: root.levels[index] ?? 0
            readonly property real size: Math.max(3, level * (root.thickness - 10))

            x: root.vertical ? (parent.width - size) / 2 : index * 4
            y: root.vertical ? index * 4 : (parent.height - size) / 2
            width: root.vertical ? size : 3
            height: root.vertical ? 3 : size
            radius: 1.5
            color: Colors.m3primary
        }
    }
}
