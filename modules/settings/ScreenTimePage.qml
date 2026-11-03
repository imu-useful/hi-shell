import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.common
import qs.common.widgets
import qs.services

// Screen time: today's apps (how long each had the focus), the week, and a daily limit per app.
ColumnLayout {
    id: root

    spacing: 24

    readonly property var todays: ScreenTime.totals(ScreenTime.today)
    readonly property int todayTotal: todays.reduce((sum, a) => sum + a.seconds, 0)
    readonly property int topSeconds: todays.length ? todays[0].seconds : 1
    readonly property var shownApps: todays.slice(0, 12)
    readonly property var week: ScreenTime.week()
    readonly property int weekPeak: Math.max(1, ...week.map(d => d.seconds))

    function duration(seconds) {
        const m = Math.floor(seconds / 60), h = Math.floor(m / 60);
        if (m === 0)
            return Translation.tr("< 1 min");
        return h ? (m % 60 ? Translation.tr("%1 h %2 min").arg(h).arg(m % 60) : Translation.tr("%1 h").arg(h)) : Translation.tr("%1 min").arg(m);
    }
    function appName(app) {
        return DesktopEntries.heuristicLookup(app)?.name ?? app;
    }
    property bool adding: false
    property int newMinutes: 30

    function usedToday(app) {
        return todays.find(a => a.app === app)?.seconds ?? 0;
    }
    function addLimit() {
        const app = ScreenTime.appKey(program.text);
        if (app === "")
            return;
        ScreenTime.setLimit(app, newMinutes);
        program.text = "";
        adding = false;
    }
    function appIcon(app) {
        // Quickshell.iconPath gives an image:// URL already.
        return AppIcons.path(app);
    }

    Section {
        icon: "hourglass_top"
        title: Translation.tr("Today")

        ListRow {
            Layout.fillWidth: true
            icon: "schedule"
            title: root.todayTotal > 0 ? root.duration(root.todayTotal) : Translation.tr("Nothing counted yet")
            subtitle: Translation.tr("Time with an app in the focus, counted every %1 seconds. Kept in ~/.local/state/hi-shell/screentime.json").arg(ScreenTime.tick)
        }

        Repeater {
            model: root.shownApps

            RowLayout {
                required property var modelData
                Layout.fillWidth: true
                Layout.leftMargin: 16
                Layout.rightMargin: 16
                spacing: 12

                Image {
                    Layout.preferredWidth: 28
                    Layout.preferredHeight: 28
                    source: root.appIcon(modelData.app)
                    sourceSize.width: 28
                    sourceSize.height: 28
                    fillMode: Image.PreserveAspectFit
                    asynchronous: true
                    visible: source !== ""
                }
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 4
                    RowLayout {
                        Layout.fillWidth: true
                        StyledText {
                            Layout.fillWidth: true
                            text: root.appName(modelData.app)
                            elide: Text.ElideRight
                        }
                        StyledText {
                            text: root.duration(modelData.seconds)
                            font.pixelSize: Appearance.font.size.labelMedium
                            color: Colors.m3onSurfaceVariant
                        }
                    }
                    Rectangle {
                        Layout.fillWidth: true
                        implicitHeight: 6
                        radius: 3
                        color: Colors.m3surfaceContainerHighest
                        Rectangle {
                            width: parent.width * modelData.seconds / root.topSeconds
                            height: parent.height
                            radius: 3
                            color: Colors.m3primary
                        }
                    }
                }
            }
        }
    }

    Section {
        icon: "calendar_view_week"
        title: Translation.tr("The last 7 days")

        RowLayout {
            Layout.fillWidth: true
            Layout.leftMargin: 16
            Layout.rightMargin: 16
            Layout.preferredHeight: 150
            spacing: 8

            Repeater {
                model: root.week

                ColumnLayout {
                    required property var modelData
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    spacing: 4

                    StyledText {
                        Layout.alignment: Qt.AlignHCenter
                        text: modelData.seconds > 0 ? root.duration(modelData.seconds) : ""
                        font.pixelSize: Appearance.font.size.labelSmall
                        color: Colors.m3onSurfaceVariant
                    }
                    Item {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        Rectangle {
                            anchors.bottom: parent.bottom
                            width: parent.width
                            height: Math.max(modelData.seconds > 0 ? 4 : 0, parent.height * modelData.seconds / root.weekPeak)
                            radius: 6
                            color: modelData.key === ScreenTime.today ? Colors.m3primary : Colors.m3primaryContainer
                        }
                    }
                    StyledText {
                        Layout.alignment: Qt.AlignHCenter
                        text: new Date(modelData.key + "T12:00").toLocaleDateString(Translation.locale, "dd")
                        font.pixelSize: Appearance.font.size.labelSmall
                    }
                }
            }
        }
    }

    Section {
        icon: "timer_off"
        title: Translation.tr("Daily limits")

        ListRow {
            Layout.fillWidth: true
            icon: "info"
            title: Translation.tr("A notification when an app's time for today runs out")
            subtitle: Translation.tr("Set the minutes for an app; 0 is no limit. Apps from today's list are shown.")
        }

        Repeater {
            model: ScreenTime.limitedApps

            StepperRow {
                required property var modelData
                icon: "hourglass_top"
                title: root.appName(modelData)
                subtitle: Translation.tr("%1 used today").arg(root.duration(root.usedToday(modelData)))
                value: ScreenTime.limitOf(modelData)
                step: 5
                from: 0
                to: 720
                onChanged: value => ScreenTime.setLimit(modelData, value)
            }
        }

        // A new limit: the program's name or command, and its minutes.
        ListRow {
            Layout.fillWidth: true
            icon: "add"
            title: Translation.tr("Add a limit")
            subtitle: Translation.tr("A program's name or command (firefox, Telegram, org.telegram.desktop)")
            IconButton {
                icon: root.adding ? "close" : "add"
                onClicked: root.adding = !root.adding
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            Layout.leftMargin: 16
            Layout.rightMargin: 16
            visible: root.adding
            spacing: 10

            Rectangle {
                Layout.fillWidth: true
                implicitHeight: 40
                radius: 20
                color: Colors.m3surfaceContainerHighest

                TextInput {
                    id: program
                    anchors.fill: parent
                    anchors.leftMargin: 16
                    anchors.rightMargin: 16
                    verticalAlignment: TextInput.AlignVCenter
                    font.family: Appearance.font.mono
                    font.pixelSize: Appearance.font.size.bodyMedium
                    color: Colors.m3onSurface
                    clip: true
                    selectByMouse: true
                    onAccepted: root.addLimit()

                    StyledText {
                        anchors.fill: parent
                        visible: program.text === ""
                        verticalAlignment: Text.AlignVCenter
                        text: Translation.tr("firefox")
                        color: Colors.m3outline
                    }
                }
            }
            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                StyledText {
                    text: Translation.tr("Minutes a day")
                    color: Colors.m3onSurfaceVariant
                }
                Item {
                    Layout.fillWidth: true
                }
                IconButton {
                    icon: "remove"
                    enabled: root.newMinutes > 5
                    onClicked: root.newMinutes -= 5
                }
                StyledText {
                    Layout.preferredWidth: 48
                    horizontalAlignment: Text.AlignHCenter
                    text: root.newMinutes
                    font.features: { "tnum": 1 }
                }
                IconButton {
                    icon: "add"
                    enabled: root.newMinutes < 720
                    onClicked: root.newMinutes += 5
                }
                M3Button {
                    text: Translation.tr("Add")
                    icon: "add"
                    enabled: program.text.trim() !== ""
                    onClicked: root.addLimit()
                }
            }
        }
    }
}
