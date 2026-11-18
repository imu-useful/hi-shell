.pragma library

// The rule editor's form (Settings > Rules) and back. A rule (common/RulesEngine.js) becomes
//   { id, name, enabled, match: "all" | "any", conds: [cond], then: [action], else: [action] }
// cond:   { type, not, ...its fields } (one per kind below; `not` wraps it in { not: .. })
// action: { kind: "set" | "ipc" | "run" | "notify" | "profile", ...its fields }
// A rule that doesn't fit (groups inside groups, a battery or screen count with odd keys, an unknown
// action) gives null from toForm and is edited as JSON.

// Kinds of conditions the form offers, in its order; `label` and `icon` are for the "Add" chips.
const condTypes = [
    { id: "batteryState", label: "Battery state", icon: "battery_charging_full" },
    { id: "batteryLevel", label: "Battery level", icon: "battery_3_bar" },
    { id: "time", label: "Time of day", icon: "schedule" },
    { id: "weekday", label: "Days of the week", icon: "calendar_month" },
    { id: "fullscreen", label: "Fullscreen window", icon: "fullscreen" },
    { id: "appOpen", label: "App is open", icon: "apps" },
    { id: "app", label: "App is focused", icon: "ads_click" },
    { id: "screen", label: "Screen connected", icon: "monitor" },
    { id: "screenCount", label: "Number of screens", icon: "desktop_windows" },
    { id: "workspace", label: "Workspace", icon: "space_dashboard" },
    { id: "dark", label: "Dark mode", icon: "dark_mode" },
    { id: "playing", label: "Media playing", icon: "music_note" },
    { id: "command", label: "A command succeeds", icon: "terminal" }
];

const actionTypes = [
    { id: "set", label: "Change an option", icon: "tune" },
    { id: "notify", label: "Show a notification", icon: "notifications" },
    { id: "ipc", label: "Call the shell", icon: "settings_remote" },
    { id: "run", label: "Run a command", icon: "terminal" },
    { id: "profile", label: "Apply a preset", icon: "inventory_2" }
];

const batteryStates = ["discharging", "charging", "full", "plugged"];
const countOps = ["is", "atLeast", "atMost", "below", "above"];

function copy(v) {
    return JSON.parse(JSON.stringify(v));
}

function newCond(type) {
    const fields = {
        batteryState: { state: "discharging" },
        batteryLevel: { below: 30, above: null },
        time: { from: "22:00", to: "07:00" },
        weekday: { days: [1, 2, 3, 4, 5] },
        fullscreen: { on: true },
        appOpen: { text: "steam" },
        app: { text: "firefox" },
        screen: { text: "HDMI-A-1" },
        screenCount: { op: "atLeast", n: 2 },
        workspace: { n: 1 },
        dark: { on: true },
        playing: { on: true },
        command: { text: "ping -c1 -W1 192.168.1.1" }
    }[type];
    return Object.assign({ type, not: false }, copy(fields ?? {}));
}

function newAction(kind) {
    const fields = {
        set: { path: "sounds.enabled", value: false, keep: false },
        notify: { text: "The rule is on" },
        ipc: { text: "theme setMode dark" },
        run: { text: "notify-send hi" },
        profile: { profile: "desk", only: "" }
    }[kind];
    return Object.assign({ kind }, copy(fields ?? {}));
}

function blank(id) {
    return { id, name: "", enabled: true, match: "all", conds: [], then: [], else: [] };
}

function plainObject(v) {
    return v !== null && typeof v === "object" && !Array.isArray(v);
}

// One condition of the engine -> a form cond, or null.
function toCond(c) {
    if (!plainObject(c) || Object.keys(c).length !== 1)
        return null;
    const key = Object.keys(c)[0], v = c[key];
    switch (key) {
    case "not": {
        const inner = toCond(v);
        return inner && !inner.not ? Object.assign(inner, { not: true }) : null;
    }
    case "battery":
        if (typeof v === "string")
            return batteryStates.includes(v) ? { type: "batteryState", not: false, state: v } : null;
        if (!plainObject(v) || Object.keys(v).some(k => k !== "below" && k !== "above"))
            return null;
        return { type: "batteryLevel", not: false, below: v.below ?? null, above: v.above ?? null };
    case "time":
        return Array.isArray(v) && v.length === 2 ? { type: "time", not: false, from: String(v[0]), to: String(v[1]) } : null;
    case "weekday":
        return Array.isArray(v) ? { type: "weekday", not: false, days: v.slice() } : null;
    case "fullscreen":
    case "dark":
    case "playing":
        return { type: key, not: false, on: v === true };
    case "app":
    case "appOpen":
    case "screen":
    case "command":
        return typeof v === "string" ? { type: key, not: false, text: v } : null;
    case "workspace":
        return typeof v === "number" ? { type: "workspace", not: false, n: v } : null;
    case "screenCount":
        if (typeof v === "number")
            return { type: "screenCount", not: false, op: "is", n: v };
        if (plainObject(v) && Object.keys(v).length === 1 && countOps.includes(Object.keys(v)[0]))
            return { type: "screenCount", not: false, op: Object.keys(v)[0], n: v[Object.keys(v)[0]] };
        return null;
    }
    return null;
}

// A form cond -> the engine's condition.
function fromCond(c) {
    let out;
    switch (c.type) {
    case "batteryState":
        out = { battery: c.state };
        break;
    case "batteryLevel": {
        const level = {};
        if (c.below !== null && c.below !== undefined)
            level.below = c.below;
        if (c.above !== null && c.above !== undefined)
            level.above = c.above;
        out = { battery: level };
        break;
    }
    case "time":
        out = { time: [c.from, c.to] };
        break;
    case "weekday":
        out = { weekday: c.days.slice().sort((a, b) => a - b) };
        break;
    case "fullscreen":
    case "dark":
    case "playing":
        out = { [c.type]: c.on === true };
        break;
    case "workspace":
        out = { workspace: c.n };
        break;
    case "screenCount":
        out = { screenCount: c.op === "is" ? c.n : { [c.op]: c.n } };
        break;
    default:
        out = { [c.type]: c.text };
    }
    return c.not ? { not: out } : out;
}

function toAction(a) {
    if (!plainObject(a))
        return null;
    if (a.set !== undefined)
        return { kind: "set", path: String(a.set), value: copy(a.value ?? null), keep: a.keep === true };
    if (a.profile !== undefined)
        return { kind: "profile", profile: String(a.profile), only: a.only ?? "" };
    for (const k of ["notify", "ipc", "run"]) {
        if (a[k] !== undefined)
            return { kind: k, text: String(a[k]) };
    }
    return null;
}

function fromAction(a) {
    switch (a.kind) {
    case "set":
        return a.keep ? { set: a.path, value: copy(a.value), keep: true } : { set: a.path, value: copy(a.value) };
    case "profile":
        return a.only ? { profile: a.profile, only: a.only } : { profile: a.profile };
    default:
        return { [a.kind]: a.text };
    }
}

// A rule -> the form, or null when it has to be edited as JSON.
function toForm(rule) {
    if (!plainObject(rule) || !plainObject(rule.when))
        return null;
    const key = Object.keys(rule.when)[0];
    const grouped = key === "all" || key === "any";
    const conds = (grouped ? Array.from(rule.when[key] ?? []) : [rule.when]).map(toCond);
    const then = Array.from(rule.then ?? []).map(toAction);
    const otherwise = Array.from(rule.else ?? []).map(toAction);
    if ([...conds, ...then, ...otherwise].some(x => x === null))
        return null;
    return {
        id: String(rule.id ?? ""),
        name: String(rule.name ?? ""),
        enabled: rule.enabled !== false,
        match: key === "any" ? "any" : "all",
        conds,
        then,
        else: otherwise
    };
}

function fromForm(form) {
    const conds = form.conds.map(fromCond);
    return {
        id: form.id,
        name: form.name,
        enabled: form.enabled !== false,
        when: conds.length === 1 ? conds[0] : { [form.match === "any" ? "any" : "all"]: conds },
        then: form.then.map(fromAction),
        else: form.else.map(fromAction)
    };
}

// An id for a new rule from its name ("Dark at night" -> "dark-at-night"), not one of `taken`.
function idFor(name, taken) {
    const base = String(name).toLowerCase().replace(/[^a-z0-9]+/g, "-").replace(/^-+|-+$/g, "").slice(0, 40) || "rule";
    let id = base, n = 2;
    while (Array.from(taken ?? []).includes(id))
        id = `${base}-${n++}`;
    return id;
}

// A typed text -> a value like `current` (the option's present value): a number, true / false, a text,
// or JSON for lists and objects. null when it doesn't read as one.
function parseValue(text, current) {
    const t = String(text).trim();
    if (typeof current === "number") {
        const n = Number(t.replace(",", "."));
        return t !== "" && isFinite(n) ? n : null;
    }
    if (typeof current === "boolean")
        return t === "true" ? true : t === "false" ? false : null;
    if (typeof current === "string")
        return String(text);
    try {
        return JSON.parse(t);
    } catch (e) {
        return current === undefined || current === null ? String(text) : null;
    }
}

// A value as it is typed in the field.
function valueText(v) {
    return typeof v === "string" ? v : JSON.stringify(v);
}

function fmt(text, args) {
    return args.reduce((s, a, i) => s.replace(`%${i + 1}`, a), text);
}

// A short reading of a condition; `tr` translates the English pieces (Translation.tr).
function describe(cond, tr) {
    const t = tr ?? (s => s);
    const f = (s, ...args) => fmt(t(s), args.map(String));
    if (!plainObject(cond))
        return "?";
    const key = Object.keys(cond)[0], v = cond[key];
    switch (key) {
    case "all":
        return Array.from(v ?? []).map(c => describe(c, t)).join(t(" and "));
    case "any":
        return "(" + Array.from(v ?? []).map(c => describe(c, t)).join(t(" or ")) + ")";
    case "not":
        return f("not %1", describe(v, t));
    case "battery":
        if (typeof v === "string")
            return t({ discharging: "on battery", charging: "charging", full: "battery full", plugged: "plugged in" }[v] ?? v);
        return [v?.below !== undefined ? f("battery below %1%", v.below) : "", v?.above !== undefined ? f("battery above %1%", v.above) : ""].filter(s => s).join(", ");
    case "fullscreen":
        return t(v ? "a fullscreen window" : "no fullscreen window");
    case "screen":
        return f("%1 is connected", v);
    case "screenCount": {
        const op = typeof v === "number" ? "is" : Object.keys(v ?? {})[0];
        const n = typeof v === "number" ? v : v?.[op];
        return f({ is: "%1 screens", atLeast: "at least %1 screens", atMost: "at most %1 screens", below: "fewer than %1 screens", above: "more than %1 screens" }[op] ?? "%1 screens", n);
    }
    case "time":
        return `${v?.[0]}–${v?.[1]}`;
    case "weekday":
        return f("on %1", Array.from(v ?? []).map(d => t(["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"][d] ?? "?")).join(", "));
    case "app":
        return f("%1 is focused", v);
    case "appOpen":
        return f("%1 is open", v);
    case "workspace":
        return f("workspace %1", v);
    case "dark":
        return t(v ? "dark mode" : "light mode");
    case "playing":
        return t(v ? "media plays" : "nothing plays");
    case "command":
        return f("`%1` succeeds", v);
    }
    return key;
}
