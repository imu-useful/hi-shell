pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.common

// Focus Mode statistics and achievements, in ~/.local/state/hi-shell/focus_stats.json:
// every finished session (start, end, profile, minutes of focus, tasks done during it),
// the achievements unlocked so far and whether the first-run tour was seen. Focus calls
// record() when a session ends; a newly reached milestone gets a congratulation.
Singleton {
    id: root

    property var sessions: [] // [{ start, end, profile, focus, tasks }]
    property var unlocked: ({}) // achievement id -> time
    property bool toured: false
    property bool loaded: false

    // --- Numbers ---
    function dayKey(time) {
        const d = new Date(time);
        return `${d.getFullYear()}-${d.getMonth() + 1}-${d.getDate()}`;
    }
    function sum(list, key) {
        return list.reduce((s, x) => s + (x[key] ?? 0), 0);
    }
    function onDay(time) {
        const key = dayKey(time);
        return sessions.filter(s => dayKey(s.end) === key);
    }

    readonly property int totalFocus: sum(sessions, "focus") // minutes
    readonly property int totalTasks: sum(sessions, "tasks")
    readonly property int todayFocus: sum(onDay(Date.now()), "focus")
    readonly property int todayTasks: sum(onDay(Date.now()), "tasks")
    // The last 7 days, oldest first: [{ time, focus, tasks }]
    readonly property var week: {
        const out = [];
        const now = new Date();
        for (let i = 6; i >= 0; i--) {
            const t = new Date(now.getFullYear(), now.getMonth(), now.getDate() - i, 12).getTime();
            const day = onDay(t);
            out.push({ time: t, focus: sum(day, "focus"), tasks: sum(day, "tasks") });
        }
        return out;
    }
    readonly property int weekFocus: sum(week, "focus")
    // Days in a row with a session, up to today (or yesterday, if today has none yet).
    readonly property int streak: {
        const days = new Set(sessions.filter(s => s.focus > 0).map(s => dayKey(s.end)));
        const now = new Date();
        let n = 0;
        for (let i = days.has(dayKey(now.getTime())) ? 0 : 1; ; i++) {
            const t = new Date(now.getFullYear(), now.getMonth(), now.getDate() - i, 12).getTime();
            if (!days.has(dayKey(t)))
                break;
            n++;
        }
        return n;
    }

    // --- Achievements ---
    // reached(): from the stats as they are now. Titles and texts are translated where shown.
    readonly property var achievements: [
        { id: "first", icon: "flag", title: "First step", text: "Finish your first focus session",
          reached: () => sessions.length >= 1 },
        { id: "hour", icon: "schedule", title: "Warming up", text: "1 hour of focus in total",
          reached: () => totalFocus >= 60 },
        { id: "deep", icon: "psychology", title: "Deep work", text: "More than 3 hours of focus in a day",
          reached: () => week.some(d => d.focus > 180) || todayFocus > 180 },
        { id: "tasks", icon: "task_alt", title: "Getting things done", text: "More than 9 tasks done",
          reached: () => totalTasks > 9 },
        { id: "tasksDay", icon: "checklist", title: "On a roll", text: "More than 9 tasks done in a day",
          reached: () => todayTasks > 9 || week.some(d => d.tasks > 9) },
        { id: "streak", icon: "local_fire_department", title: "Habit", text: "Focus 5 days in a row",
          reached: () => streak >= 5 },
        { id: "ten", icon: "military_tech", title: "Marathon", text: "10 hours of focus in total",
          reached: () => totalFocus >= 600 },
        { id: "fifty", icon: "workspace_premium", title: "Master of focus", text: "50 hours of focus in total",
          reached: () => totalFocus >= 3000 }
    ]

    // A finished session; returns the achievements it unlocked.
    function record(session) {
        sessions = [...sessions, session];
        const fresh = achievements.filter(a => !unlocked[a.id] && a.reached());
        if (fresh.length) {
            const all = Object.assign({}, unlocked);
            fresh.forEach(a => all[a.id] = session.end);
            unlocked = all;
        }
        save();
        fresh.forEach((a, i) => congratulate.createObject(root, { achievement: a, delay: 1500 + i * 2500 }));
        return fresh;
    }

    Component {
        id: congratulate
        Timer {
            property var achievement
            property int delay
            interval: delay
            running: true
            onTriggered: {
                Quickshell.execDetached(["notify-send", "-a", Translation.tr("Focus Mode"), "-i", "trophy-symbolic",
                    Translation.tr("Achievement: %1").arg(Translation.tr(achievement.title)), Translation.tr(achievement.text)]);
                destroy();
            }
        }
    }

    function setToured() {
        toured = true;
        save();
    }

    // --- File ---
    function save() {
        if (loaded)
            file.setText(JSON.stringify({ version: 1, sessions: sessions, unlocked: unlocked, toured: toured }, null, 1) + "\n");
    }

    FileView {
        id: file
        path: `${Paths.state}/focus_stats.json`
        atomicWrites: true
        printErrors: false
        onLoaded: {
            try {
                const d = JSON.parse(text());
                root.sessions = Array.isArray(d.sessions) ? d.sessions : [];
                root.unlocked = d.unlocked ?? {};
                root.toured = !!d.toured;
            } catch (e) {
                console.warn("FocusStats: bad file", e);
            }
            root.loaded = true;
        }
        onLoadFailed: root.loaded = true
    }

    IpcHandler {
        target: "focusStats"

        function summary(): string {
            return `today ${root.todayFocus} min, ${root.todayTasks} tasks; week ${root.weekFocus} min; total ${root.totalFocus} min, ${root.totalTasks} tasks; streak ${root.streak}; sessions ${root.sessions.length}; achievements ${Object.keys(root.unlocked).join(",")}`;
        }
        // Show the first-run tour again next time the Focus Mode window opens.
        function resetTour(): void {
            root.toured = false;
            root.save();
        }
    }
}
