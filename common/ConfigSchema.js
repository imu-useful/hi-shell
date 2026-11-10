.pragma library

// Rules for options whose value must stay in a known set or range. Config.qml checks them after the file
// loads (and after every hand edit): a value that breaks its rule is reported and put back to `def`.
// Options without a rule are left alone. Paths are the dotted names in Config.options.
//   enum: allowed values   min / max: numeric range   def: the value to fall back to
const rules = {
    "language": { enum: ["auto", "en", "ru"], def: "auto", allowOther: true }, // custom languages add codes
    "appearance.transparencyLevel": { min: 0, max: 1, def: 0.12 },
    "appearance.animationSpeed": { min: 0, max: 4, def: 1 },
    "appearance.motionStyle": { enum: ["expressive", "smooth", "snappy"], def: "expressive" },
    "appearance.popupEffect": { enum: ["pop", "drop", "slide", "fade"], def: "pop" },
    "appearance.sidebarEffect": { enum: ["slide", "pop", "fade"], def: "slide" },
    "appearance.paletteFade": { min: 0, max: 2000, def: 400 },
    "appearance.launcherEffect": { enum: ["rise", "pop", "fade"], def: "rise" },
    "appearance.panelSpeed": { min: 0.25, max: 4, def: 1 },
    "appearance.barSpeed": { min: 0.25, max: 4, def: 1 },
    "appearance.notificationSpeed": { min: 0.25, max: 4, def: 1 },
    "appearance.pressScale": { min: 0.7, max: 1, def: 0.9 },
    "appearance.surfaceStyle": { enum: ["tonal", "glass", "flat"], def: "tonal" },
    "appearance.borderWidth": { min: -1, max: 4, def: -1 },
    "appearance.textWeight": { enum: ["light", "normal", "medium"], def: "normal" },
    "appearance.letterSpacing": { min: -1, max: 3, def: 0 },
    "appearance.animationBounce": { min: 0, max: 2, def: 1 },
    "appearance.cornerScale": { min: 0, max: 2, def: 1 },
    "appearance.fontScale": { min: 0.6, max: 2, def: 1 },
    "appearance.density": { enum: ["compact", "comfortable", "spacious"], def: "comfortable" },
    "appearance.seedColor": { pattern: "^#[0-9a-fA-F]{6}$", allowEmpty: true, def: "" },
    "appearance.contrast": { min: -1, max: 1, def: 0 },
    "appearance.screenCorners": { min: 0, max: 64, def: 16 },
    "appearance.contextMenu": { enum: ["material", "caelestia", "standard"], def: "material" },
    "appearance.scheme": { enum: ["tonal-spot", "content", "expressive", "fidelity", "fruit-salad", "monochrome", "neutral", "rainbow", "vibrant"], def: "tonal-spot" },
    "bar.position": { enum: ["top", "bottom", "left", "right"], def: "top" },
    "bar.style": { enum: ["hug", "float", "islands", "m3"], def: "float" },
    "bar.height": { min: 20, max: 120, def: 40 },
    "bar.margin": { min: 0, max: 64, def: 6 },
    "bar.workspaces.shown": { min: 1, max: 20, def: 10 },
    "bar.workspaces.appsPerWorkspace": { min: 0, max: 10, def: 3 },
    "bar.workspaces.switchStyle": { enum: ["slide", "stretch"], def: "slide" },
    "bar.island.holdDuration": { min: 200, max: 10000, def: 2000 },
    "bar.media.maxWidth": { min: 60, max: 800, def: 220 },
    "sidebar.quickToggles.style": { enum: ["android", "classic"], def: "android" },
    "sidebar.quickToggles.perPage": { min: 0, max: 30, def: 6 },
    "sidebar.nightLightTemperature": { min: 1000, max: 10000, def: 4500 },
    "wallpapers.slideshowMinutes": { min: 0, max: 100000, def: 0 },
    "wallpapers.frameX": { min: 0, max: 1, def: 0.5 },
    "wallpapers.frameY": { min: 0, max: 1, def: 0.5 },
    "wallpapers.frameSize": { min: 0.1, max: 2, def: 0.62 },
    "idle.lockMin": { min: 0, max: 1440, def: 5 },
    "idle.screenOffMin": { min: 0, max: 1440, def: 10 },
    "idle.suspendMin": { min: 0, max: 1440, def: 15 },
    "idle.batLockMin": { min: 0, max: 1440, def: 2 },
    "idle.batScreenOffMin": { min: 0, max: 1440, def: 3 },
    "idle.batSuspendMin": { min: 0, max: 1440, def: 5 },
    "lock.mode": { enum: ["builtin", "hyprlock", "file", "command"], def: "builtin" },
    "lock.align": { enum: ["center", "left", "right"], def: "center" },
    "lock.accent": { enum: ["primary", "secondary", "tertiary"], def: "primary" },
    "lock.fieldShape": { enum: ["round", "square"], def: "round" },
    "lock.clockSize": { min: 20, max: 400, def: 120 },
    "lock.avatarSize": { min: 32, max: 400, def: 116 },
    "lock.fieldWidth": { min: 120, max: 800, def: 320 },
    "lock.fieldOutline": { min: 0, max: 12, def: 2 },
    "lock.blurPasses": { min: 0, max: 8, def: 3 },
    "lock.blurSize": { min: 0, max: 64, def: 8 },
    "lock.brightness": { min: 0, max: 1, def: 0.55 },
    "greeting.style": { enum: ["random", "rise", "drop", "pop", "slide", "spin"], def: "random" },
    "ai.provider": { enum: ["claude", "openrouter", "openai", "gemini", "groq", "deepseek", "mistral", "ollama", "custom"], def: "claude" },
    "weather.latitude": { min: -90, max: 90, def: 0 },
    "weather.longitude": { min: -180, max: 180, def: 0 },
    "weather.refreshMinutes": { min: 1, max: 1440, def: 15 },
    "battery.low": { min: 1, max: 100, def: 20 },
    "battery.critical": { min: 1, max: 100, def: 10 },
    "notifications.defaultTimeout": { min: 500, max: 600000, def: 6000 },
    "notifications.historyLimit": { min: 0, max: 5000, def: 100 },
    "updates.intervalMinutes": { min: 5, max: 10080, def: 60 },
    "dock.position": { enum: ["bottom", "top", "left", "right"], def: "bottom" },
    "dock.magnifyAmount": { min: 0, max: 200, def: 45 },
    "dock.spacing": { min: 0, max: 40, def: 2 },
    "dock.cornerRadius": { min: 0, max: 64, def: 28 },
    "dock.edgeMargin": { min: 0, max: 64, def: 8 },
    "dock.iconSize": { min: 16, max: 128, def: 44 },
    "sounds.volume": { min: 0, max: 1, def: 0.7 },
    "capture.recordSound": { enum: ["off", "system", "mic"], def: "off" },
    "update.channel": { enum: ["git", "release"], def: "git" },
    "processes.mode": { enum: ["builtin", "command"], def: "builtin" }
};

// Why `value` breaks the rule for `path`, or "" if it is fine (or the path has no rule).
function problem(path, value) {
    const r = rules[path];
    if (!r)
        return "";
    if (r.pattern) {
        if (r.allowEmpty && value === "")
            return "";
        return typeof value === "string" && new RegExp(r.pattern).test(value) ? "" : "must look like #rrggbb";
    }
    if (r.enum) {
        if (r.allowOther && typeof value === "string" && value !== "")
            return "";
        return r.enum.includes(value) ? "" : `must be one of: ${r.enum.join(", ")}`;
    }
    if (typeof value !== "number" || isNaN(value))
        return "must be a number";
    if (value < r.min || value > r.max)
        return `must be between ${r.min} and ${r.max}`;
    return "";
}

// Paths of the options that break their rule, as [{ path, value, reason, def }].
// `read(path)` returns the option's current value.
function check(read) {
    const bad = [];
    for (const path in rules) {
        const value = read(path);
        if (value === undefined)
            continue;
        const reason = problem(path, value);
        if (reason)
            bad.push({ path, value, reason, def: rules[path].def });
    }
    return bad;
}
