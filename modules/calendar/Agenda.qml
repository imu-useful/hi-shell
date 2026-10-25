import QtQuick
import QtQuick.Layouts
import qs.common

// Event list: upcoming events grouped by day, or a single selected day.
// Also shows setup / sign-in / error states of the calendar backend.
ColumnLayout {
    id: root

    property string selectedDay: ""

    readonly property string todayIso: Calendar.iso(new Date())
    readonly property string tomorrowIso: {
        const d = new Date();
        return Calendar.iso(new Date(d.getFullYear(), d.getMonth(), d.getDate() + 1));
    }

    function dayLabel(iso) {
        if (iso === todayIso)
            return "Today";
        if (iso === tomorrowIso)
            return "Tomorrow";
        const [y, m, d] = iso.split("-").map(Number);
        return Qt.formatDate(new Date(y, m - 1, d), "dddd, d MMMM");
    }

    // Flat list of {header} and {event} rows.
    readonly property var rows: {
        const out = [];
        if (selectedDay !== "") {
            out.push({ header: dayLabel(selectedDay) });
            for (const ev of Calendar.eventsByDay[selectedDay] ?? [])
                out.push({ event: ev });
            return out;
        }
        // Upcoming: each event once, under its first day that is today or later.
        let lastDay = "";
        for (const ev of Calendar.events) {
            const day = ev.days.find(d => d >= todayIso);
            if (!day)
                continue;
            if (!ev.allDay && day === todayIso && new Date(ev.end) < new Date())
                continue;
            if (day !== lastDay) {
                out.push({ header: dayLabel(day) });
                lastDay = day;
            }
            out.push({ event: ev, day: day });
        }
        return out;
    }
    readonly property int eventCount: rows.filter(r => r.event).length

    spacing: 8

    RowLayout {
        Layout.fillWidth: true

        Text {
            Layout.fillWidth: true
            Layout.leftMargin: 8
            text: root.selectedDay !== "" ? "Day" : "Upcoming"
            font.family: Style.fontFamily
            font.pixelSize: 16
            font.weight: Font.Medium
            color: Colors.m3onSurface
        }

        Spinner {
            visible: Calendar.loading
            implicitWidth: 18
            implicitHeight: 18
            lineWidth: 2
        }

        IconButton {
            icon: "refresh"
            visible: Calendar.status === "ok"
            enabled: !Calendar.loading
            onClicked: Calendar.refresh()
        }
    }

    // Events
    ListView {
        id: list
        Layout.fillWidth: true
        Layout.fillHeight: true
        visible: Calendar.status === "ok" && root.eventCount > 0
        clip: true
        spacing: 6
        model: root.rows
        boundsBehavior: Flickable.StopAtBounds

        delegate: Loader {
            required property var modelData
            width: list.width
            sourceComponent: modelData.header !== undefined ? headerRow : eventRow

            Component {
                id: headerRow
                Text {
                    topPadding: 6
                    leftPadding: 8
                    text: modelData.header
                    font.family: Style.fontFamily
                    font.pixelSize: 12
                    font.weight: Font.Medium
                    color: Colors.m3primary
                }
            }

            Component {
                id: eventRow
                EventItem {
                    event: modelData.event
                }
            }
        }
    }

    // Empty / setup / error states
    ColumnLayout {
        Layout.fillWidth: true
        Layout.fillHeight: true
        visible: !list.visible
        spacing: 12

        Item { Layout.fillHeight: true }

        Text {
            Layout.alignment: Qt.AlignHCenter
            text: Calendar.status === "error" ? "error" : Calendar.status === "ok" ? "event_available" : "calendar_month"
            font.family: Style.iconFont
            font.pixelSize: 40
            color: Calendar.status === "error" ? Colors.m3error : Colors.m3onSurfaceVariant
        }

        Text {
            Layout.fillWidth: true
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.Wrap
            font.family: Style.fontFamily
            font.pixelSize: 14
            color: Colors.m3onSurface
            text: {
                if (Calendar.connecting)
                    return "Finish signing in in your browser…";
                switch (Calendar.status) {
                case "idle":
                    return "Loading events…";
                case "ok":
                    return root.selectedDay !== "" ? "Nothing scheduled" : "No upcoming events";
                case "needs_setup":
                    return "Set up Google Calendar";
                case "needs_auth":
                    return "Connect your Google account";
                default:
                    return "Couldn't load events";
                }
            }
        }

        Text {
            Layout.fillWidth: true
            visible: text !== ""
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.Wrap
            font.family: Style.fontFamily
            font.pixelSize: 12
            color: Colors.m3onSurfaceVariant
            text: Calendar.status === "needs_setup"
                ? "Save a Google OAuth client (type “Desktop app”) as\n~/.config/hi-shell/google-client.json\nSee README for the steps."
                : (Calendar.status === "error" || Calendar.status === "needs_auth") ? Calendar.message : ""
        }

        M3Button {
            Layout.alignment: Qt.AlignHCenter
            visible: Calendar.status === "needs_auth" && !Calendar.connecting
            icon: "login"
            text: "Connect Google Calendar"
            onClicked: Calendar.connect()
        }

        M3Button {
            Layout.alignment: Qt.AlignHCenter
            visible: Calendar.status === "error" || Calendar.status === "needs_setup"
            tonal: true
            icon: "refresh"
            text: "Retry"
            enabled: !Calendar.loading
            onClicked: Calendar.refresh()
        }

        Item { Layout.fillHeight: true }
    }
}
