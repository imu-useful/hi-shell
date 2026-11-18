.pragma library

// Bedtime: when the reminder is due. Pure functions, so tests can run them in node.

// Minutes after midnight of "HH:MM", or -1 when it isn't a time.
function minutesOf(text) {
    const m = /^([01]?\d|2[0-3]):([0-5]\d)$/.exec(String(text ?? "").trim());
    return m ? Number(m[1]) * 60 + Number(m[2]) : -1;
}

function pad(n) {
    return String(n).padStart(2, "0");
}

function dayKey(date) {
    return `${date.getFullYear()}-${pad(date.getMonth() + 1)}-${pad(date.getDate())}`;
}

// The night `now` is in, as the date of its evening ("YYYY-MM-DD"), or "" when it is
// not bedtime: between `bedtime` and `wake` ("HH:MM"), the span may cross midnight.
// After midnight the night still belongs to the evening before, so "Not today" at
// 22:00 keeps it quiet at 01:00 too.
function nightOf(now, bedtime, wake) {
    const b = minutesOf(bedtime), w = minutesOf(wake);
    if (b < 0 || w < 0 || b === w)
        return "";
    const m = now.getHours() * 60 + now.getMinutes();
    if (b < w)
        return m >= b && m < w ? dayKey(now) : "";
    if (m >= b)
        return dayKey(now);
    if (m < w) {
        const evening = new Date(now.getFullYear(), now.getMonth(), now.getDate() - 1);
        return dayKey(evening);
    }
    return "";
}

// Whether the reminder shows now: on, in a night that wasn't dismissed, past any snooze.
function due(now, opts, state) {
    if (!opts.enabled)
        return false;
    const night = nightOf(now, opts.time, opts.wake);
    return night !== "" && night !== state.skippedNight && now.getTime() >= (state.snoozedUntil ?? 0);
}
