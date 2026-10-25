import QtQuick
import QtQuick.Layouts
import qs.common

// One agenda entry: calendar color bar, title, time and location.
// Click opens the event in Google Calendar; the camera button joins Meet.
Rectangle {
    id: root

    required property var event

    readonly property var start: new Date(event.start)
    readonly property var end: new Date(event.end)
    readonly property bool ongoing: !event.allDay && start <= now.date && now.date < end

    implicitHeight: content.implicitHeight + 20
    radius: 16
    color: ongoing ? Colors.m3primaryContainer : mouse.containsMouse ? Colors.m3surfaceContainerHighest : Colors.m3surfaceContainerHigh

    Behavior on color { ColorAnimation { duration: 120 } }

    QtObject {
        id: now
        property var date: new Date()
    }

    Timer {
        interval: 60000
        running: root.visible
        repeat: true
        onTriggered: now.date = new Date()
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: root.event.link ? Qt.PointingHandCursor : Qt.ArrowCursor
        onClicked: if (root.event.link) Qt.openUrlExternally(root.event.link)
    }

    RowLayout {
        id: content
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        anchors.leftMargin: 12
        anchors.rightMargin: 8
        spacing: 12

        Rectangle {
            Layout.fillHeight: true
            implicitWidth: 4
            radius: 2
            color: root.event.color || Colors.m3primary
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 2

            Text {
                Layout.fillWidth: true
                text: root.event.title
                elide: Text.ElideRight
                font.family: Style.fontFamily
                font.pixelSize: 14
                font.weight: Font.Medium
                color: root.ongoing ? Colors.m3onPrimaryContainer : Colors.m3onSurface
            }

            Text {
                Layout.fillWidth: true
                text: {
                    const time = root.event.allDay ? "All day" : `${Qt.formatTime(root.start, "HH:mm")} – ${Qt.formatTime(root.end, "HH:mm")}`;
                    return [root.ongoing ? "Now" : "", time, root.event.location].filter(s => s).join(" · ");
                }
                elide: Text.ElideRight
                font.family: Style.fontFamily
                font.pixelSize: 12
                color: root.ongoing ? Colors.m3onPrimaryContainer : Colors.m3onSurfaceVariant
            }
        }

        IconButton {
            visible: root.event.meet !== ""
            icon: "videocam"
            onClicked: Qt.openUrlExternally(root.event.meet)
        }
    }
}
