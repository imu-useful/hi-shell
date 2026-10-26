import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.common
import qs.common.widgets
import qs.services

// Focus Mode session next to the clock (only while one runs): the profile's icon, the
// time focused so far and a stop button.
BarWidget {
    id: root

    shown: Focus.active
    active: true
    padding: 4
    contentWidth: vertical ? thickness : row.implicitWidth + 4
    contentHeight: column.implicitHeight

    property real now: Date.now()
    Timer {
        running: Focus.active
        interval: 1000
        repeat: true
        triggeredOnStart: true
        onTriggered: root.now = Date.now()
    }
    readonly property int seconds: Math.max(0, Math.floor((now - Focus.startedAt) / 1000))
    readonly property string elapsed: {
        const h = Math.floor(seconds / 3600), m = Math.floor(seconds / 60) % 60, s = seconds % 60;
        const two = n => String(n).padStart(2, "0");
        return h ? `${h}:${two(m)}:${two(s)}` : `${two(m)}:${two(s)}`;
    }

    RowLayout {
        id: row
        visible: !root.vertical
        anchors.centerIn: parent
        spacing: 6

        MaterialIcon {
            Layout.leftMargin: 6
            icon: Focus.sessionProfile.icon ?? "center_focus_strong"
            iconSize: 18
            fill: 1
            color: Colors.m3primary
        }
        StyledText {
            text: root.elapsed
            font.weight: Font.DemiBold
            font.features: { "tnum": 1 }
        }
        IconButton {
            implicitWidth: root.thickness - 8
            implicitHeight: root.thickness - 8
            icon: "stop"
            iconColor: Colors.m3error
            tooltip: Translation.tr("Stop Focus Mode")
            onClicked: Focus.stop()
        }
    }

    ColumnLayout {
        id: column
        visible: root.vertical
        anchors.centerIn: parent
        spacing: 2

        MaterialIcon {
            Layout.alignment: Qt.AlignHCenter
            icon: Focus.sessionProfile.icon ?? "center_focus_strong"
            iconSize: 18
            fill: 1
            color: Colors.m3primary
        }
        StyledText {
            Layout.alignment: Qt.AlignHCenter
            text: Math.floor(root.seconds / 60)
            font.weight: Font.DemiBold
            font.features: { "tnum": 1 }
        }
        IconButton {
            Layout.alignment: Qt.AlignHCenter
            implicitWidth: root.thickness - 4
            implicitHeight: root.thickness - 4
            icon: "stop"
            iconColor: Colors.m3error
            onClicked: Focus.stop()
        }
    }
}
