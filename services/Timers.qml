pragma Singleton

import QtQuick
import Quickshell

// Focus (pomodoro), stopwatch and countdown timers. Times are in seconds.
Singleton {
    id: root

    // --- Focus: work / break cycles ---
    property int focusMinutes: 25
    property int breakMinutes: 5
    property bool focusRunning: false
    property bool onBreak: false
    property real focusLeft: focusMinutes * 60

    function toggleFocus() {
        focusRunning = !focusRunning;
    }
    function resetFocus() {
        focusRunning = false;
        onBreak = false;
        focusLeft = focusMinutes * 60;
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
                    root.notify("Timer finished", "Countdown is over");
                }
            }

            if (root.focusRunning) {
                root.focusLeft -= dt;
                if (root.focusLeft <= 0) {
                    root.onBreak = !root.onBreak;
                    root.focusLeft = (root.onBreak ? root.breakMinutes : root.focusMinutes) * 60;
                    root.notify(root.onBreak ? "Time for a break" : "Back to focus",
                                root.onBreak ? `${root.breakMinutes} minute break` : `${root.focusMinutes} minutes of focus`);
                }
            }
        }
    }
}
