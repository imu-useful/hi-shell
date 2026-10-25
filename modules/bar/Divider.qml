import QtQuick
import qs.common

// Thin separator between widgets.
BarWidget {
    id: root

    pill: false
    padding: 4
    contentWidth: 1
    contentHeight: 1

    Rectangle {
        anchors.centerIn: parent
        width: root.vertical ? 16 : 1
        height: root.vertical ? 1 : 16
        color: Colors.m3outlineVariant
    }
}
