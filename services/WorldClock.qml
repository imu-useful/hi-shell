pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.common

// Local time in other timezones (Config desktop.worldClocks, IANA names like
// "Asia/Tokyo"), computed with `date` once a minute since QML has no tz database.
Singleton {
    id: root

    // [{ zone, city, time ("05:36"), offset ("+9"), isDay }]
    property var clocks: []
    readonly property list<string> zones: Config.options.desktop.worldClocks

    function refresh() {
        if (zones.length === 0) {
            clocks = [];
            return;
        }
        proc.command = ["sh", "-c", 'for z in "$@"; do TZ="$z" date "+$z|%H:%M|%z"; done', "sh", ...zones];
        proc.running = true;
    }

    onZonesChanged: refresh()

    Process {
        id: proc
        stdout: StdioCollector {
            onStreamFinished: {
                root.clocks = text.trim().split("\n").filter(l => l.includes("|")).map(l => {
                    const [zone, time, offset] = l.split("|");
                    const h = Number(time.slice(0, 2));
                    // "+0900" -> "+9", "+0530" -> "+5:30"
                    const sign = offset[0], oh = Number(offset.slice(1, 3)), om = offset.slice(3);
                    return {
                        zone,
                        city: zone.split("/").pop().replace(/_/g, " "),
                        time,
                        offset: `UTC${sign}${oh}${om !== "00" ? ":" + om : ""}`,
                        isDay: h >= 7 && h < 19
                    };
                });
            }
        }
    }

    // Align refreshes to the minute.
    Timer {
        running: root.zones.length > 0
        repeat: true
        interval: 60000 - Date.now() % 60000 + 200
        triggeredOnStart: true
        onTriggered: {
            interval = 60000 - Date.now() % 60000 + 200;
            root.refresh();
        }
    }
}
