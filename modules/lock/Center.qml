import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.common
import qs.common.widgets
import qs.common.shapes
import qs.services

// The middle column: the time (hours in the primary color, minutes in the secondary), the date,
// the avatar in a clamshell, the password pill and the message under it.
ColumnLayout {
    id: root

    required property var lock
    required property real scaleFactor

    Layout.preferredWidth: 420 * scaleFactor
    Layout.fillWidth: false
    Layout.fillHeight: true
    spacing: Appearance.space.lg

    SystemClock {
        id: clock
        precision: SystemClock.Minutes
    }

    Row {
        Layout.alignment: Qt.AlignHCenter
        Layout.topMargin: Appearance.space.lg
        spacing: Appearance.space.sm

        StyledText {
            text: Qt.formatTime(clock.date, "HH")
            color: Colors.m3primary
            font.family: Appearance.font.title
            font.pixelSize: 120 * root.scaleFactor
            font.weight: Font.Black
            font.features: { "tnum": 1 }
        }
        StyledText {
            text: Qt.formatTime(clock.date, "mm")
            color: Colors.m3secondary
            font.family: Appearance.font.title
            font.pixelSize: 120 * root.scaleFactor
            font.weight: Font.Black
            font.features: { "tnum": 1 }
        }
    }

    StyledText {
        Layout.alignment: Qt.AlignHCenter
        text: Translation.locale.toString(clock.date, "dddd • d MMM").toUpperCase()
        font.family: Appearance.font.title
        font.pixelSize: Appearance.font.size.titleLarge * root.scaleFactor
        font.weight: Font.DemiBold
    }

    Item {
        Layout.alignment: Qt.AlignHCenter
        Layout.topMargin: Appearance.space.xl * root.scaleFactor
        implicitWidth: 200 * root.scaleFactor
        implicitHeight: implicitWidth

        MaterialShape {
            anchors.fill: parent
            shape: "cookie9"
            color: Colors.m3surfaceContainerHighest
        }
        MaterialIcon {
            anchors.centerIn: parent
            icon: "person"
            fill: 1
            iconSize: parent.width / 3
            visible: face.status !== Image.Ready
        }
        ShapeImage {
            id: face
            anchors.fill: parent
            shape: "cookie9"
            source: `file://${Paths.home}/.face`
        }
    }

    Item { Layout.fillHeight: true }

    PasswordInput {
        Layout.alignment: Qt.AlignHCenter
        Layout.preferredWidth: root.width * 0.85
        lock: root.lock
    }

    StateMessage {
        Layout.fillWidth: true
        Layout.preferredHeight: implicitHeight
        pam: root.lock.pam
    }

    Item { Layout.fillHeight: true }
}
