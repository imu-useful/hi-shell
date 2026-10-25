import QtQuick
import Quickshell
import qs.common
import qs.common.widgets
import qs.services

// Mini audio spectrum from cava; only runs while media is playing.
BarWidget {
    id: root

    readonly property int bars: 10

    shown: Mpris.playing
    padding: 10
    contentWidth: bars * 4 - 1
    contentHeight: bars * 4 - 1

    Spectrum {
        anchors.centerIn: parent
        width: root.vertical ? root.thickness - 10 : root.contentWidth
        height: root.vertical ? root.contentHeight : root.thickness - 10
        active: root.visible
        bars: root.bars
        gap: 1
        mode: root.vertical ? "stacked" : "center"
        color: Colors.m3primary
    }
}
