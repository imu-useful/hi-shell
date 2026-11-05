pragma Singleton

import QtQuick
import Quickshell
import qs.common

// Focus (pomodoro), stopwatch and countdown timers. Times are in seconds.
Singleton {
    id: root

    // --- Focus: work / break cycles ---
    property int focusMinutes: 25
    property int breakMinutes: 5
    property bool focusRunning: false
    property bool onBreak: false
    property real focusLeft: focusMinutes * 60
    // The length of a focus period in seconds: from the settings' minutes, or typed in the sidebar.
    property real focusTotal: focusMinutes * 60

    function toggleFocus() {
        focusRunning = !focusRunning;
    }
    function resetFocus() {
        focusRunning = false;
        onBreak = false;
        focusLeft = focusTotal;
    }
    // A new length for the focus period, while it isn't running.
    function setFocusTime(seconds) {
        if (focusRunning || onBreak || seconds <= 0)
            return;
        focusTotal = seconds;
        focusLeft = seconds;
    }

    // --- Stopwatch ---
    property bool stopwatchRunning: false
    property real stopwatchElapsed: 0
    property list<real> laps: []

    function toggleStopwatch() {
        stopwatchRunning = !stopwatchRunning;
    }
    function lap() {
        laps = [stopwatchElapsed, ...laps];
    }
    function resetStopwatch() {
        stopwatchRunning = false;
        stopwatchElapsed = 0;
        laps = [];
    }

    // --- Countdown ---
    property real countdownTotal: 0
    property real countdownLeft: 0
    property bool countdownRunning: false

    // A new length for the countdown, while it isn't running.
    function setCountdownTime(seconds) {
        if (countdownRunning || seconds <= 0)
            return;
        countdownTotal = seconds;
        countdownLeft = seconds;
    }
    function addCountdown(seconds) {
        countdownTotal = countdownLeft + seconds;
        countdownLeft += seconds;
    }
    function toggleCountdown() {
        if (countdownLeft > 0)
            countdownRunning = !countdownRunning;
    }
    function resetCountdown() {
        countdownRunning = false;
        countdownLeft = 0;
        countdownTotal = 0;
    }

    // Typed times: "25" (minutes), "25:30" (minutes:seconds), "1:02:03", "25m", "30s". -1 when it isn't one.
    function parse(text) {
        const t = text.trim().toLowerCase();
        let m = /^(\d+)\s*m(in)?$/.exec(t);
        if (m)
            return Number(m[1]) * 60;
        m = /^(\d+)\s*s(ec)?$/.exec(t);
        if (m)
            return Number(m[1]);
        if (!/^\d+(:\d{1,2}){0,2}$/.test(t))
            return -1;
        const parts = t.split(":").map(Number);
        if (parts.length === 1)
            return parts[0] * 60;
        if (parts.length === 2)
            return parts[0] * 60 + parts[1];
        return parts[0] * 3600 + parts[1] * 60 + parts[2];
    }

    // "4:05", "1:02:03"
    function format(seconds) {
        const s = Math.max(0, Math.round(seconds));
        const h = Math.floor(s / 3600), m = Math.floor(s % 3600 / 60), sec = String(s % 60).padStart(2, "0");
        return h > 0 ? `${h}:${String(m).padStart(2, "0")}:${sec}` : `${m}:${sec}`;
    }

    function notify(title, body) {
        Quickshell.execDetached(["notify-send", "-a", "hi-shell", "-i", "alarm-symbolic", title, body]);
    }

    // One clock for all three; wall-clock based so it doesn't drift.
    property real last: Date.now()
    Timer {
        interval: 250
        repeat: true
        running: root.focusRunning || root.stopwatchRunning || root.countdownRunning
        onRunningChanged: root.last = Date.now()
        onTriggered: {
            const now = Date.now();
            const dt = (now - root.last) / 1000;
            root.last = now;

            if (root.stopwatchRunning)
                root.stopwatchElapsed += dt;

            if (root.countdownRunning) {
                root.countdownLeft = Math.max(0, root.countdownLeft - dt);
                if (root.countdownLeft === 0) {
                    root.countdownRunning = false;
                    root.countdownTotal = 0;
                    root.notify(Translation.tr("Timer finished"), Translation.tr("Countdown is over"));
                }
            }

            if (root.focusRunning) {
                root.focusLeft -= dt;
                if (root.focusLeft <= 0) {
                    root.onBreak = !root.onBreak;
                    root.focusLeft = (root.onBreak ? root.breakMinutes : root.focusMinutes) * 60;
                    root.notify(root.onBreak ? Translation.tr("Time for a break") : Translation.tr("Back to focus"),
                                root.onBreak ? Translation.trn("%1 minute break", "%1 minute break", root.breakMinutes) : Translation.trn("%1 minute of focus", "%1 minutes of focus", root.focusMinutes));
                }
            }
        }
    }
}
