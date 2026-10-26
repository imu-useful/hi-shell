import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.common
import qs.common.widgets
import qs.services

// Focus Mode session next to the clock (only while one runs): the Pomodoro phase, the
// time left in it and the cycle, plus a stop button in Manual mode.
BarWidget {
    id: root

    readonly property bool onBreak: Focus.phase.kind === "short" || Focus.phase.kind === "long"
    readonly property color accent: onBreak ? Colors.m3tertiary : Colors.m3primary
    readonly property string icon: Focus.phase.kind === "short" ? "coffee" : Focus.phase.kind === "long" ? "self_improvement" : "psychology"
    readonly property string timeLeft: {
        const s = Focus.remaining, h = Math.floor(s / 3600), m = Math.floor(s / 60) % 60;
        const two = n => String(n).padStart(2, "0");
        return h ? `${h}:${two(m)}:${two(s % 60)}` : `${two(m)}:${two(s % 60)}`;
    }
    // 0..1 through the current phase.
    readonly property real progress: Focus.phase.end > Focus.phase.start ? 1 - Focus.remaining * 1000 / (Focus.phase.end - Focus.phase.start) : 0

    shown: Focus.active
    active: true
    padding: 4
    contentWidth: vertical ? thickness : row.implicitWidth + 4
    contentHeight: column.implicitHeight

    RowLayout {
        id: row
        visible: !root.vertical
        anchors.centerIn: parent
        spacing: 6

        CircularProgress {
            Layout.leftMargin: 4
            implicitWidth: root.thickness - 8
            implicitHeight: root.thickness - 8
            value: root.progress
            color: root.accent
            MaterialIcon {
                anchors.centerIn: parent
                icon: root.icon
                iconSize: 15
                fill: 1
                color: root.accent
            }
        }
        StyledText {
            text: root.timeLeft
            font.weight: Font.DemiBold
            font.features: { "tnum": 1 }
        }
        StyledText {
            Layout.rightMargin: Focus.canStop ? 0 : 6
            text: `${Focus.phase.cycle}/${Focus.sessionProfile.timer?.cycles ?? 0}`
            font.pixelSize: Appearance.font.size.labelMedium
            color: Colors.m3onSurfaceVariant
        }
        IconButton {
            visible: Focus.canStop
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
            icon: root.icon
            iconSize: 18
            fill: 1
            color: root.accent
        }
        StyledText {
            Layout.alignment: Qt.AlignHCenter
            text: Math.ceil(Focus.remaining / 60)
            font.weight: Font.DemiBold
            font.features: { "tnum": 1 }
        }
        IconButton {
            visible: Focus.canStop
            Layout.alignment: Qt.AlignHCenter
            implicitWidth: root.thickness - 4
            implicitHeight: root.thickness - 4
            icon: "stop"
            iconColor: Colors.m3error
            onClicked: Focus.stop()
        }
    }
}
