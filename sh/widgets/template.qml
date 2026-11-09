import QtQuick
import Quickshell.Io
import qs.common
import qs.common.widgets
import qs.modules.bar

// A bar widget of your own. Put its name (the file name without .qml) in a bar list, e.g. with
//   hi bar add mybar top __NAME__
// or in Settings > Bar. Save the file and the bar picks the change up.
// Options of a copy ("__NAME__#work" in the list) are in `instance`, set with
//   hi bar instance '__NAME__#work' '{"label": "Work"}'
BarWidget {
    id: root

    // Hidden while false; the widget stays in the list.
    shown: true
    clickable: true
    padding: 10
    contentWidth: label.implicitWidth
    contentHeight: label.implicitHeight

    // Poll runs a command now and then. `pick` reads an option of this copy, else the fallback.
    Poll {
        id: poll
        command: "date +%H:%M:%S"
        interval: 1
    }

    StyledText {
        id: label
        anchors.centerIn: parent
        text: root.pick("label", "Hello") + " " + poll.output
        color: Colors.m3onSurface
        font.pixelSize: Appearance.font.size.normal
    }

    onClicked: console.log("__NAME__ clicked")
}
