import QtQuick
import QtQuick.Layouts
import qs.common
import qs.common.widgets
import qs.services

// First-run introduction over the Focus Mode window: a few cards on how blocking, the
// Pomodoro timer and exiting work, each opening the tab it's about. Shown once (until
// "Show the introduction again" on the Stats tab); Skip ends it.
Item {
    id: root

    readonly property bool shown: FocusStats.loaded && !FocusStats.toured
    property int step: 0

    readonly property var steps: [
        { tab: "timer", icon: "center_focus_strong", title: Translation.tr("Welcome to Focus Mode"),
          text: Translation.tr("A session hides distractions: a minimal bar, no widgets or animations, and the apps and sites you choose blocked. Here's how it works in four steps.") },
        { tab: "timer", icon: "timer", title: Translation.tr("Pomodoro"),
          text: Translation.tr("Work in focus periods with short breaks between them and a long one after the last cycle. A notification tells you when each starts. During breaks nothing is blocked.") },
        { tab: "lists", icon: "block", title: Translation.tr("Blocking"),
          text: Translation.tr("Blocked apps are closed as soon as they open, and browser tabs with blocked sites too. Blocking sites asks for your password once when the session starts.") },
        { tab: "exit", icon: "logout", title: Translation.tr("How it ends"),
          text: Translation.tr("Manual: a Stop button. Timer: it ends when the cycles are over. Tasks: when the tasks picked for it are done. Settings and the left sidebar are locked until then.") },
        { tab: "stats", icon: "rocket_launch", title: Translation.tr("Ready"),
          text: Translation.tr("Start a session with the button below, or with the Focus Mode tile in the right sidebar. Your focus time and achievements are on the Statistics tab.") }
    ]
    readonly property var current: steps[step]

    function finish() {
        FocusStats.setToured();
        step = 0;
        Focus.settingsTab = "timer";
    }

    visible: opacity > 0
    opacity: shown ? 1 : 0
    Behavior on opacity { EffectAnim {} }
    onShownChanged: if (shown) { step = 0; Focus.settingsTab = steps[0].tab; }
    onStepChanged: if (shown) Focus.settingsTab = steps[step].tab

    // Scrim: the window shows through, but takes no clicks.
    Rectangle {
        anchors.fill: parent
        color: Qt.alpha("#000000", 0.45)
        MouseArea {
            anchors.fill: parent
            hoverEnabled: true
        }
    }

    Rectangle {
        id: card
        anchors.centerIn: parent
        width: Math.min(parent.width - 64, 460)
        height: content.implicitHeight + 48
        radius: Appearance.rounding.extraLarge
        color: Colors.m3surfaceContainerHigh

        scale: root.shown ? 1 : 0.9
        Behavior on scale { SpringAnim {} }

        ColumnLayout {
            id: content
            anchors.fill: parent
            anchors.margins: 24
            spacing: 14

            Rectangle {
                implicitWidth: 56
                implicitHeight: 56
                radius: 18
                color: Colors.m3primaryContainer
                MaterialIcon {
                    anchors.centerIn: parent
                    icon: root.current.icon
                    fill: 1
                    iconSize: 30
                    color: Colors.m3onPrimaryContainer
                }
            }
            StyledText {
                Layout.fillWidth: true
                text: root.current.title
                wrapMode: Text.WordWrap
                font.pixelSize: Appearance.font.size.headlineSmall
            }
            StyledText {
                Layout.fillWidth: true
                text: root.current.text
                wrapMode: Text.WordWrap
                lineHeight: 1.2
                color: Colors.m3onSurfaceVariant
            }

            RowLayout {
                Layout.fillWidth: true
                Layout.topMargin: 8
                spacing: 8

                // Step dots
                Row {
                    spacing: 6
                    Repeater {
                        model: root.steps.length
                        Rectangle {
                            required property int index
                            width: index === root.step ? 20 : 8
                            height: 8
                            radius: 4
                            color: index === root.step ? Colors.m3primary : Colors.m3outlineVariant
                            Behavior on width { SpringAnim {} }
                        }
                    }
                }
                Item { Layout.fillWidth: true }
                StyledText {
                    visible: root.step < root.steps.length - 1
                    text: Translation.tr("Skip")
                    font.weight: Font.Medium
                    color: Colors.m3primary
                    MouseArea {
                        anchors.fill: parent
                        anchors.margins: -10
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.finish()
                    }
                }
                M3Button {
                    Layout.leftMargin: 8
                    text: root.step < root.steps.length - 1 ? Translation.tr("Next") : Translation.tr("Got it")
                    onClicked: root.step < root.steps.length - 1 ? root.step++ : root.finish()
                }
            }
        }
    }
}
