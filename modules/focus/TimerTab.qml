import QtQuick
import QtQuick.Layouts
import qs.common
import qs.common.widgets
import qs.services
import qs.modules.settings

// Pomodoro: focus and break lengths, cycles, and how the session will run.
ColumnLayout {
    id: root

    readonly property var timer: Focus.profile.timer
    // Focus, break, focus, break… with a long break after the last cycle.
    readonly property var segments: {
        const out = [];
        for (let i = 0; i < timer.cycles; i++) {
            out.push({ kind: "focus", minutes: timer.focus });
            out.push(i < timer.cycles - 1 ? { kind: "short", minutes: timer.shortBreak } : { kind: "long", minutes: timer.longBreak });
        }
        return out;
    }
    readonly property int total: segments.reduce((sum, s) => sum + s.minutes, 0)

    function duration(minutes) {
        const h = Math.floor(minutes / 60), m = minutes % 60;
        return h ? (m ? Translation.tr("%1 h %2 min").arg(h).arg(m) : Translation.tr("%1 h").arg(h)) : Translation.tr("%1 min").arg(m);
    }

    spacing: 20

    Section {
        icon: "timer"
        title: Translation.tr("Pomodoro")

        StepperRow {
            icon: "psychology"
            title: Translation.tr("Focus")
            subtitle: Translation.tr("Minutes of work in one cycle")
            value: root.timer.focus
            from: 5
            to: 180
            step: 5
            onChanged: value => Focus.set("timer.focus", value)
        }
        StepperRow {
            icon: "coffee"
            title: Translation.tr("Short break")
            subtitle: Translation.tr("Between cycles")
            value: root.timer.shortBreak
            from: 1
            to: 30
            onChanged: value => Focus.set("timer.shortBreak", value)
        }
        StepperRow {
            icon: "self_improvement"
            title: Translation.tr("Long break")
            subtitle: Translation.tr("After the last cycle")
            value: root.timer.longBreak
            from: 5
            to: 60
            step: 5
            onChanged: value => Focus.set("timer.longBreak", value)
        }
        StepperRow {
            icon: "replay"
            title: Translation.tr("Cycles")
            subtitle: Translation.tr("Focus periods before the long break")
            value: root.timer.cycles
            from: 1
            to: 12
            onChanged: value => Focus.set("timer.cycles", value)
        }
    }

    Section {
        icon: "view_timeline"
        title: Translation.tr("Session")

        ColumnLayout {
            Layout.fillWidth: true
            Layout.margins: 14
            spacing: 12

            // Each segment as wide as it is long.
            Row {
                id: line
                Layout.fillWidth: true
                spacing: 3

                Repeater {
                    model: root.segments
                    Rectangle {
                        required property var modelData
                        width: Math.max(4, (line.width - line.spacing * (root.segments.length - 1)) * modelData.minutes / root.total)
                        height: 28
                        radius: 8
                        color: modelData.kind === "focus" ? Colors.m3primary
                             : modelData.kind === "long" ? Colors.m3tertiary : Colors.m3secondaryContainer
                        Behavior on width { SpringAnim {} }
                    }
                }
            }

            RowLayout {
                spacing: 16
                Repeater {
                    model: [
                        { text: Translation.tr("Focus"), color: Colors.m3primary },
                        { text: Translation.tr("Short break"), color: Colors.m3secondaryContainer },
                        { text: Translation.tr("Long break"), color: Colors.m3tertiary }
                    ]
                    RowLayout {
                        required property var modelData
                        spacing: 6
                        Rectangle {
                            implicitWidth: 10
                            implicitHeight: 10
                            radius: 5
                            color: modelData.color
                        }
                        StyledText {
                            text: modelData.text
                            font.pixelSize: Appearance.font.size.labelMedium
                            color: Colors.m3onSurfaceVariant
                        }
                    }
                }
                Item { Layout.fillWidth: true }
                StyledText {
                    text: Translation.tr("%1 focused · %2 in total").arg(root.duration(root.timer.focus * root.timer.cycles)).arg(root.duration(root.total))
                    font.weight: Font.Medium
                }
            }
        }
    }
}
