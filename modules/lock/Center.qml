import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.common
import qs.common.widgets
import qs.common.shapes
import qs.services

// The middle: the time on one line, the date, the avatar in a ring, a greeting and the password pill.
ColumnLayout {
    id: root

    required property var lock
    required property real scaleFactor

    spacing: Appearance.space.sm

    SystemClock {
        id: clock
        precision: SystemClock.Seconds
    }

    // HH:mm stays in the middle; the seconds hang off its right edge, smaller, in the secondary color.
    Item {
        Layout.alignment: Qt.AlignHCenter
        implicitWidth: time.implicitWidth
        implicitHeight: time.implicitHeight

        StyledText {
            id: time
            text: Qt.formatTime(clock.date, "HH:mm")
            color: Colors.m3primary
            font.family: Appearance.font.title
            font.pixelSize: 168 * root.scaleFactor
            font.weight: Font.Black
            font.features: { "tnum": 1 }
            style: Text.Outline
            styleColor: Qt.alpha("black", 0.12)
        }
        StyledText {
            anchors.left: time.right
            anchors.leftMargin: Appearance.space.sm
            anchors.baseline: time.baseline
            text: Qt.formatTime(clock.date, "ss")
            color: Colors.m3secondary
            font.family: Appearance.font.title
            font.pixelSize: 64 * root.scaleFactor
            font.weight: Font.Black
            font.features: { "tnum": 1 }
        }
    }

    StyledText {
        Layout.alignment: Qt.AlignHCenter
        Layout.topMargin: -Appearance.space.lg
        text: Translation.locale.toString(clock.date, "dddd, d MMMM")
        font.family: Appearance.font.title
        font.pixelSize: Appearance.font.size.headlineSmall
        font.weight: Font.Medium
    }

    Item {
        Layout.alignment: Qt.AlignHCenter
        Layout.topMargin: Appearance.space.xxl * root.scaleFactor
        implicitWidth: 112
        implicitHeight: 112

        Rectangle {
            anchors.fill: parent
            radius: width / 2
            color: "transparent"
            border.width: 3
            border.color: Colors.m3primary
        }
        Rectangle {
            anchors.fill: parent
            anchors.margins: 6
            radius: width / 2
            color: Colors.m3surfaceContainerHighest
        }
        MaterialIcon {
            anchors.centerIn: parent
            icon: "person"
            fill: 1
            iconSize: 48
            visible: face.status !== Image.Ready
        }
        ShapeImage {
            id: face
            anchors.fill: parent
            anchors.margins: 6
            shape: "circle"
            source: `file://${Paths.home}/.face`
        }
    }

    StyledText {
        Layout.alignment: Qt.AlignHCenter
        readonly property int hour: Number(Qt.formatTime(clock.date, "H"))
        text: `${hour < 5 ? Translation.tr("Good night") : hour < 12 ? Translation.tr("Good morning") : hour < 18 ? Translation.tr("Good afternoon") : Translation.tr("Good evening")}, ${Quickshell.env("USER")}`
        font.pixelSize: Appearance.font.size.titleMedium
        color: Colors.m3onSurfaceVariant
    }

    PasswordInput {
        Layout.alignment: Qt.AlignHCenter
        Layout.topMargin: Appearance.space.md
        Layout.preferredWidth: 340
        lock: root.lock
    }

    StateMessage {
        Layout.alignment: Qt.AlignHCenter
        Layout.preferredWidth: 340
        Layout.preferredHeight: implicitHeight
        pam: root.lock.pam
    }
}
