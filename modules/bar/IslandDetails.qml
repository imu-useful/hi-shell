import QtQuick
import QtQuick.Layouts
import qs.common
import qs.common.widgets
import qs.services

// The notification's text inside the island grown open (under its face, which keeps the icon and the
// title): the app, the whole title, the body and the buttons. No background: the island is it.
ColumnLayout {
    id: root

    property bool shown: false
    readonly property var notif: Island.notif

    width: 340
    spacing: 2

    StyledText {
        Layout.fillWidth: true
        text: root.notif?.appName ?? ""
        font.pixelSize: Appearance.font.size.labelMedium
        color: Colors.m3outline
        elide: Text.ElideRight
    }
    StyledText {
        Layout.fillWidth: true
        visible: text !== ""
        text: root.notif?.summary ?? ""
        font.weight: Font.Medium
        wrapMode: Text.Wrap
        maximumLineCount: 2
    }
    StyledText {
        Layout.fillWidth: true
        visible: text !== ""
        text: root.notif?.body ?? ""
        textFormat: Text.StyledText
        font.pixelSize: Appearance.font.size.labelMedium + 1
        color: Colors.m3onSurfaceVariant
        wrapMode: Text.Wrap
        maximumLineCount: 4
        elide: Text.ElideRight
        linkColor: Colors.m3primary
        onLinkActivated: link => Qt.openUrlExternally(link)
    }
    IslandActions {
        visible: Island.buttons.length > 0
        Layout.topMargin: 10
        Layout.alignment: Qt.AlignHCenter
        shown: root.shown
        delay: Appearance.anim.fast
    }
}
