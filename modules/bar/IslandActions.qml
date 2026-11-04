import QtQuick
import QtQuick.Layouts
import qs.common
import qs.common.widgets
import qs.services

// The buttons of the island's notification (Island.buttons: "Read", "Reply", ...), as pills that pop
// out one after another, bouncing; with `floating` they also drift up and down slowly (over a
// fullscreen window, where they are always out). `shown` pulls them in and out.
Row {
    id: root

    property bool shown: false
    property bool floating: false
    // Wait before the first one pops, for the island to land first.
    property int delay: 0

    spacing: 8

    Repeater {
        model: Island.buttons

        Rectangle {
            id: button

            required property var modelData
            required property int index

            property real pop: root.shown ? 1 : 0
            Behavior on pop {
                SequentialAnimation {
                    PauseAnimation { duration: root.shown ? root.delay + button.index * 80 : 0 }
                    SpringAnim { overshoot: root.shown ? 3 : 1; duration: root.shown ? 650 : Appearance.anim.normal }
                }
            }

            // Slow bobbing, each button a little out of step.
            property real bob: 0
            SequentialAnimation on bob {
                running: root.floating && root.shown
                loops: Animation.Infinite
                PauseAnimation { duration: button.index * 260 }
                NumberAnimation { to: -3; duration: 1100; easing.type: Easing.InOutSine }
                NumberAnimation { to: 3; duration: 1100; easing.type: Easing.InOutSine }
            }

            implicitWidth: label.implicitWidth + 28
            implicitHeight: 32
            radius: height / 2
            color: modelData.reply ? Colors.m3primary : Colors.m3secondaryContainer
            border.width: 1
            border.color: Qt.alpha(Colors.m3outlineVariant, 0.6)
            scale: Math.max(0, pop)
            opacity: Math.min(1, pop)
            transform: Translate { y: button.bob }

            StyledText {
                id: label
                anchors.centerIn: parent
                text: button.modelData.text
                font.pixelSize: Appearance.font.size.normal
                font.weight: Font.Medium
                color: button.modelData.reply ? Colors.m3onPrimary : Colors.m3onSecondaryContainer
            }

            StateLayer {
                tint: label.color
                onClicked: Island.press(button.modelData)
            }
        }
    }
}
