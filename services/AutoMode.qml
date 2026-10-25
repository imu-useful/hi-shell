pragma Singleton

import QtQuick
import Quickshell
import qs.common

// Config appearance.autoMode: light from sunrise to sunset, dark otherwise,
// using today's times for the weather location (06:00 / 19:00 until known).
Singleton {
    id: root

    readonly property bool enabled: Config.options.appearance.autoMode

    function wantedMode() {
        const now = new Date();
        const today = Weather.daily[0];
        const hhmm = d => d.getHours() * 60 + d.getMinutes();
        // Open-Meteo times are local to the location ("2026-10-25T06:49").
        const minutes = s => Number(s.slice(11, 13)) * 60 + Number(s.slice(14, 16));
        const sunrise = today ? minutes(today.sunrise) : 6 * 60;
        const sunset = today ? minutes(today.sunset) : 19 * 60;
        const t = hhmm(now);
        return t >= sunrise && t < sunset ? "light" : "dark";
    }

    function apply() {
        if (!enabled)
            return;
        const mode = wantedMode();
        if (mode !== Colors.mode)
            Theme.setMode(mode);
    }

    onEnabledChanged: apply()

    Timer {
        running: root.enabled
        interval: 60000
        repeat: true
        triggeredOnStart: true
        onTriggered: root.apply()
    }
}
