import QtQuick
import qs.common
import qs.common.widgets

// Keys "sudo", "arch", "42": a line of text typed out in a terminal-style font.
Item {
    id: root

    required property bool revealed
    required property string message
    property string prompt: "$ "
    property int shown: 0

    Timer {
        interval: 45
        running: root.revealed && root.shown < root.message.length
        repeat: true
        onTriggered: root.shown++
    }

    StyledText {
        anchors.centerIn: parent
        width: parent.width * 0.8
        horizontalAlignment: Text.AlignHCenter
        wrapMode: Text.Wrap
        elide: Text.ElideNone
        font.family: Appearance.font.mono
        font.pixelSize: Math.min(48, root.width / 26)
        color: "#1fdc4a"
        text: root.prompt + root.message.slice(0, root.shown) + (cursor.on ? "█" : " ")

        Timer {
            id: cursor
            property bool on: true
            interval: 500
            running: root.revealed
            repeat: true
            onTriggered: on = !on
        }
    }
}
