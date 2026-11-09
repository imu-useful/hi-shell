.pragma library

// Rules: "when this is true, do that" (Config rules). A rule is
//   { id, name, enabled, when: <condition>, then: [<action>...], else: [<action>...] }
// `then` runs when `when` turns true; when it turns false the values `then` set are put back and `else` runs.
//
// Conditions (one key each; combine with all / any / not):
//   { battery: "discharging" | "charging" | "full" | "plugged" | { below: 30, above: 10 } }
//   { fullscreen: true }                 a fullscreen window is on a screen
//   { screen: "HDMI-A-1" }               that screen is connected
//   { screenCount: { atLeast: 2 } }      (also atMost, below, above, or a plain number)
//   { time: ["22:00", "07:00"] }         from .. to, past midnight too
//   { weekday: [1, 2, 3, 4, 5] }         0 = Sunday
//   { app: "firefox" }                   the focused window's class has this in it (any case)
//   { appOpen: "steam" }                 some window's class has this in it
//   { workspace: 3 }
//   { dark: true }                       dark mode is on
//   { playing: true }                    media is playing
//   { command: "nmcli -t -f ACTIVE,SSID dev wifi | grep -q '^yes:Home$'" }   exits with 0 (checked every 30 s)
//   { all: [..] }  { any: [..] }  { not: <condition> }
//
// Actions:
//   { set: "bar.height", value: 30 }     a config option; put back when the rule ends (unless keep: true)
//   { ipc: "theme setMode dark" }        qs ipc call <target> <function> [args]
//   { run: "notify-send hi" }            a shell command
//   { notify: "Battery saver is on" }    a notification
//
// Facts (what the conditions look at): { battery: { available, percent, charging, full, onBattery }, fullscreen, screens: [names],
// time: minutes since midnight, weekday, app, apps: [classes], workspace, dark, playing, commands: { command: bool } }

function isList(v) {
    return Array.isArray(v) || (v !== null && typeof v === "object" && typeof v.length === "number");
}

const WORDS = ["battery", "fullscreen", "screen", "screenCount", "time", "weekday", "app", "appOpen", "workspace", "dark", "playing", "command", "all", "any", "not"];

function compare(spec, n) {
    if (typeof spec === "number")
        return n === spec;
    if (spec === null || typeof spec !== "object")
        return false;
    if (spec.below !== undefined && !(n < spec.below))
        return false;
    if (spec.above !== undefined && !(n > spec.above))
        return false;
    if (spec.atLeast !== undefined && !(n >= spec.atLeast))
        return false;
    if (spec.atMost !== undefined && !(n <= spec.atMost))
        return false;
    return true;
}

function minutesOf(text) {
    const m = /^(\d{1,2}):(\d{2})$/.exec(String(text));
    if (!m)
        return -1;
    const h = Number(m[1]), mm = Number(m[2]);
    return h > 23 || mm > 59 ? -1 : h * 60 + mm;
}

// `from` .. `to` (minutes since midnight), going past midnight when from > to.
function inRange(range, now) {
    if (!isList(range))
        return false;
    const from = minutesOf(range[0]), to = minutesOf(range[1]);
    if (from < 0 || to < 0)
        return false;
    if (from === to)
        return true;
    return from < to ? now >= from && now < to : now >= from || now < to;
}

function has(list, text) {
    const t = String(text).toLowerCase();
    return Array.from(list ?? []).some(x => String(x).toLowerCase().includes(t));
}

function evaluate(cond, f) {
    if (cond === null || typeof cond !== "object")
        return false;
    const key = Object.keys(cond)[0];
    const v = cond[key];
    const b = f.battery ?? {};
    switch (key) {
    case "all":
        return Array.isArray(v) && v.length > 0 && v.every(c => evaluate(c, f));
    case "any":
        return Array.isArray(v) && v.some(c => evaluate(c, f));
    case "not":
        return !evaluate(v, f);
    case "battery":
        if (v === "discharging")
            return !!b.available && !!b.onBattery && !b.charging;
        if (v === "charging")
            return !!b.charging;
        if (v === "full")
            return !!b.full;
        if (v === "plugged")
            return !b.onBattery;
        return !!b.available && compare(v, b.percent);
    case "fullscreen":
        return (f.fullscreen === true) === (v === true);
    case "screen":
        return Array.from(f.screens ?? []).includes(v);
    case "screenCount":
        return compare(v, Array.from(f.screens ?? []).length);
    case "time":
        return inRange(v, f.time ?? 0);
    case "weekday":
        return Array.from(v ?? []).includes(f.weekday);
    case "app":
        return has([f.app ?? ""], v) && (f.app ?? "") !== "";
    case "appOpen":
        return has(f.apps, v);
    case "workspace":
        return f.workspace === v;
    case "dark":
        return (f.dark === true) === (v === true);
    case "playing":
        return (f.playing === true) === (v === true);
    case "command":
        return (f.commands ?? {})[v] === true;
    }
    return false;
}

// Why a condition is no good, or "" if it is fine.
function validateCondition(cond, depth) {
    if (cond === null || typeof cond !== "object" || Array.isArray(cond))
        return "a condition is an object like { \"battery\": \"discharging\" }";
    if ((depth ?? 0) > 8)
        return "conditions are nested too deep";
    const keys = Object.keys(cond);
    if (keys.length !== 1)
        return "a condition has exactly one key (use all / any to combine): " + keys.join(", ");
    const key = keys[0], v = cond[key];
    if (!WORDS.includes(key))
        return `unknown condition "${key}"`;
    if (key === "all" || key === "any") {
        if (!Array.isArray(v) || v.length === 0)
            return `${key} needs a list of conditions`;
        for (const c of v) {
            const e = validateCondition(c, (depth ?? 0) + 1);
            if (e)
                return e;
        }
    } else if (key === "not") {
        return validateCondition(v, (depth ?? 0) + 1);
    } else if (key === "battery") {
        if (!["discharging", "charging", "full", "plugged"].includes(v) && (v === null || typeof v !== "object"))
            return "battery is discharging, charging, full, plugged or { below, above }";
    } else if (key === "time") {
        if (!Array.isArray(v) || v.length !== 2 || minutesOf(v[0]) < 0 || minutesOf(v[1]) < 0)
            return "time is [\"HH:MM\", \"HH:MM\"]";
    } else if (key === "weekday") {
        if (!Array.isArray(v) || !v.every(d => Number.isInteger(d) && d >= 0 && d <= 6))
            return "weekday is a list of 0 (Sunday) .. 6";
    } else if (["screen", "app", "appOpen", "command"].includes(key)) {
        if (typeof v !== "string" || v === "")
            return `${key} is a non-empty text`;
    } else if (key === "workspace") {
        if (!Number.isInteger(v))
            return "workspace is a number";
    } else if (["fullscreen", "dark", "playing"].includes(key)) {
        if (typeof v !== "boolean")
            return `${key} is true or false`;
    } else if (key === "screenCount") {
        if (typeof v !== "number" && (v === null || typeof v !== "object"))
            return "screenCount is a number or { atLeast, atMost, below, above }";
    }
    return "";
}

function validateAction(a) {
    if (a === null || typeof a !== "object" || Array.isArray(a))
        return "an action is an object like { \"ipc\": \"theme setMode dark\" }";
    if (a.set !== undefined) {
        if (typeof a.set !== "string" || !/^[A-Za-z][A-Za-z0-9]*(\.[A-Za-z][A-Za-z0-9]*)*$/.test(a.set))
            return "set needs an option path like bar.height";
        if (a.value === undefined)
            return `set ${a.set} needs a value`;
        return "";
    }
    for (const k of ["ipc", "run", "notify"]) {
        if (a[k] !== undefined)
            return typeof a[k] === "string" && a[k].trim() !== "" ? "" : `${k} is a non-empty text`;
    }
    return "an action has set + value, ipc, run or notify";
}

// Why a rule is no good, or "" if it is fine.
function validateRule(rule) {
    if (rule === null || typeof rule !== "object" || Array.isArray(rule))
        return "a rule is an object";
    if (typeof rule.id !== "string" || !/^[A-Za-z0-9_-]+$/.test(rule.id))
        return "id is letters, digits, - and _";
    const w = validateCondition(rule.when, 0);
    if (w)
        return "when: " + w;
    for (const part of ["then", "else"]) {
        const list = rule[part];
        if (list === undefined && part === "else")
            continue;
        if (!isList(list))
            return `${part} is a list of actions`;
        for (const a of Array.from(list)) {
            const e = validateAction(a);
            if (e)
                return `${part}: ${e}`;
        }
    }
    return "";
}

// Every `command` in a condition (they are polled).
function commands(cond, out) {
    out = out ?? [];
    if (cond === null || typeof cond !== "object")
        return out;
    const key = Object.keys(cond)[0];
    const v = cond[key];
    if (key === "command" && typeof v === "string" && !out.includes(v))
        out.push(v);
    else if (key === "all" || key === "any")
        Array.from(v ?? []).forEach(c => commands(c, out));
    else if (key === "not")
        commands(v, out);
    return out;
}

// A short English reading of a condition.
function describe(cond) {
    if (cond === null || typeof cond !== "object")
        return "?";
    const key = Object.keys(cond)[0];
    const v = cond[key];
    switch (key) {
    case "all":
        return Array.from(v ?? []).map(describe).join(" and ");
    case "any":
        return "(" + Array.from(v ?? []).map(describe).join(" or ") + ")";
    case "not":
        return "not " + describe(v);
    case "battery":
        return typeof v === "string" ? `battery ${v}` : `battery ${v.below !== undefined ? "below " + v.below + "%" : ""}${v.above !== undefined ? " above " + v.above + "%" : ""}`.trim();
    case "fullscreen":
        return v ? "a fullscreen window" : "no fullscreen window";
    case "screen":
        return `${v} is connected`;
    case "screenCount":
        return "screens: " + (typeof v === "number" ? v : JSON.stringify(v));
    case "time":
        return `${v[0]}–${v[1]}`;
    case "weekday":
        return "on " + Array.from(v).map(d => ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"][d]).join(", ");
    case "app":
        return `${v} is focused`;
    case "appOpen":
        return `${v} is open`;
    case "workspace":
        return `workspace ${v}`;
    case "dark":
        return v ? "dark mode" : "light mode";
    case "playing":
        return v ? "media plays" : "nothing plays";
    case "command":
        return `\`${v}\` succeeds`;
    }
    return key;
}

// Rules to start from (hi rules add <name>, Settings > Rules).
const templates = {
    "battery-saver": {
        name: "Power saving on battery below 30%",
        when: { all: [{ battery: "discharging" }, { battery: { below: 30 } }] },
        then: [{ ipc: "powersaving on" }],
        else: [{ ipc: "powersaving off" }]
    },
    "night-dark": {
        name: "Dark mode from 20:00 to 07:00",
        when: { time: ["20:00", "07:00"] },
        then: [{ ipc: "theme setMode dark" }],
        else: [{ ipc: "theme setMode light" }]
    },
    "fullscreen-quiet": {
        name: "No sounds over a fullscreen window",
        when: { fullscreen: true },
        then: [{ set: "sounds.enabled", value: false }]
    },
    "docked": {
        name: "A dock on every screen with a second screen",
        when: { screenCount: { atLeast: 2 } },
        then: [{ set: "dock.monitors", value: ["*"] }]
    },
    "game-mode": {
        name: "Presentation mode while Steam is open",
        when: { appOpen: "steam_app" },
        then: [{ ipc: "presentation on" }],
        else: [{ ipc: "presentation off" }]
    }
};
