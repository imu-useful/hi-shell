import QtQuick
import QtQuick.Layouts
import qs.common
import qs.common.widgets
import qs.services

// The notification's text, in a second small island under the first: the app, the title and the body.
// Pops out with a bounce when `shown`.
Rectangle {
    id: root

    property bool shown: false
    readonly property var notif: Island.notif

    property real pop: shown ? 1 : 0
    Behavior on pop { SpringAnim { overshoot: shown ? 2.4 : 1; duration: shown ? 600 : Appearance.anim.normal } }

    implicitWidth: 320
    implicitHeight: column.implicitHeight + 24
    radius: Appearance.rounding.large
    color: Appearance.translucent(Colors.m3surfaceContainerHighest, 0.05)
    border.width: 1
    border.color: Qt.alpha(Colors.m3outlineVariant, 0.6)
    // Only the background grows: scaling the text would have it drawn again on every frame.
    opacity: Math.min(1, pop)
    transform: Translate { y: (1 - Math.min(1, root.pop)) * -12 }

    ColumnLayout {
        id: column
        x: 16
        y: 12
        width: parent.width - 32
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
    }
}
