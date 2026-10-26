import QtQuick
import QtQuick.Layouts
import qs.common
import qs.common.widgets
import qs.services
import qs.modules.settings

// Focus statistics: today, the week as a chart, the streak, and the achievements.
ColumnLayout {
    id: root

    function duration(minutes) {
        const h = Math.floor(minutes / 60), m = minutes % 60;
        return h ? (m ? Translation.tr("%1 h %2 min").arg(h).arg(m) : Translation.tr("%1 h").arg(h)) : Translation.tr("%1 min").arg(m);
    }

    spacing: 20

    // --- Numbers ---
    GridLayout {
        Layout.fillWidth: true
        columns: 4
        columnSpacing: 10
        rowSpacing: 10

        Repeater {
            model: [
                { icon: "timer", value: root.duration(FocusStats.todayFocus), label: Translation.tr("Focus today") },
                { icon: "task_alt", value: String(FocusStats.todayTasks), label: Translation.tr("Tasks today") },
                { icon: "date_range", value: root.duration(FocusStats.weekFocus), label: Translation.tr("This week") },
                { icon: "local_fire_department", value: Translation.trn("%1 day", "%1 days", FocusStats.streak), label: Translation.tr("Streak") }
            ]
            Rectangle {
                required property var modelData
                Layout.fillWidth: true
                implicitHeight: 96
                radius: Appearance.rounding.large
                color: Colors.m3surfaceContainer

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 14
                    spacing: 2
                    MaterialIcon {
                        icon: modelData.icon
                        fill: 1
                        iconSize: 20
                        color: Colors.m3primary
                    }
                    Item { Layout.fillHeight: true }
                    StyledText {
                        Layout.fillWidth: true
                        text: modelData.value
                        elide: Text.ElideRight
                        font.pixelSize: Appearance.font.size.titleLarge
                        font.weight: Font.Medium
                    }
                    StyledText {
                        text: modelData.label
                        font.pixelSize: Appearance.font.size.labelMedium
                        color: Colors.m3onSurfaceVariant
                    }
                }
            }
        }
    }

    // --- The week ---
    Section {
        icon: "bar_chart"
        title: Translation.tr("Last 7 days")

        Item {
            id: chart
            Layout.fillWidth: true
            Layout.margins: 14
            implicitHeight: 170
            readonly property int peak: Math.max(60, ...FocusStats.week.map(d => d.focus))

            RowLayout {
                anchors.fill: parent
                spacing: 10

                Repeater {
                    model: FocusStats.week

                    ColumnLayout {
                        id: day
                        required property var modelData
                        required property int index
                        readonly property bool today: index === 6

                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        spacing: 6

                        StyledText {
                            Layout.alignment: Qt.AlignHCenter
                            text: day.modelData.focus ? root.duration(day.modelData.focus) : ""
                            font.pixelSize: Appearance.font.size.labelSmall
                            color: Colors.m3onSurfaceVariant
                        }
                        Item {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            Rectangle {
                                anchors.bottom: parent.bottom
                                anchors.horizontalCenter: parent.horizontalCenter
                                width: Math.min(parent.width, 36)
                                height: Math.max(6, parent.height * day.modelData.focus / chart.peak)
                                radius: 8
                                color: day.today ? Colors.m3primary : day.modelData.focus ? Colors.m3secondary : Colors.m3surfaceContainerHighest
                                Behavior on height { SpringAnim {} }
                            }
                        }
                        StyledText {
                            Layout.alignment: Qt.AlignHCenter
                            text: new Date(day.modelData.time).toLocaleString(Translation.locale, "ddd")
                            font.weight: day.today ? Font.DemiBold : Font.Normal
                            font.pixelSize: Appearance.font.size.labelMedium
                            color: day.today ? Colors.m3primary : Colors.m3onSurfaceVariant
                        }
                    }
                }
            }
        }

        ListRow {
            Layout.fillWidth: true
            icon: "functions"
            title: Translation.tr("All time")
            subtitle: Translation.tr("%1 of focus · %2 · %3")
                .arg(root.duration(FocusStats.totalFocus))
                .arg(Translation.trn("%1 task", "%1 tasks", FocusStats.totalTasks))
                .arg(Translation.trn("%1 session", "%1 sessions", FocusStats.sessions.length))
        }
    }

    // --- Achievements ---
    Section {
        icon: "emoji_events"
        title: Translation.tr("Achievements · %1 of %2").arg(Object.keys(FocusStats.unlocked).length).arg(FocusStats.achievements.length)

        GridLayout {
            Layout.fillWidth: true
            Layout.margins: 8
            columns: 2
            columnSpacing: 8
            rowSpacing: 8

            Repeater {
                model: FocusStats.achievements

                Rectangle {
                    id: badge
                    required property var modelData
                    readonly property bool got: !!FocusStats.unlocked[modelData.id]

                    Layout.fillWidth: true
                    implicitHeight: 64
                    radius: Appearance.rounding.medium
                    color: got ? Colors.m3tertiaryContainer : Colors.m3surfaceContainerHigh
                    opacity: got ? 1 : 0.6

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 12
                        anchors.rightMargin: 12
                        spacing: 12
                        MaterialIcon {
                            icon: badge.got ? badge.modelData.icon : "lock"
                            fill: badge.got ? 1 : 0
                            iconSize: 26
                            color: badge.got ? Colors.m3onTertiaryContainer : Colors.m3onSurfaceVariant
                        }
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 0
                            StyledText {
                                Layout.fillWidth: true
                                text: Translation.tr(badge.modelData.title)
                                elide: Text.ElideRight
                                font.weight: Font.Medium
                                color: badge.got ? Colors.m3onTertiaryContainer : Colors.m3onSurface
                            }
                            StyledText {
                                Layout.fillWidth: true
                                text: Translation.tr(badge.modelData.text)
                                elide: Text.ElideRight
                                font.pixelSize: Appearance.font.size.labelMedium
                                color: badge.got ? Colors.m3onTertiaryContainer : Colors.m3onSurfaceVariant
                            }
                        }
                    }
                }
            }
        }
    }

    ListRow {
        Layout.fillWidth: true
        icon: "tour"
        title: Translation.tr("Show the introduction again")
        clickable: true
        onClicked: FocusStats.toured = false
    }
}
