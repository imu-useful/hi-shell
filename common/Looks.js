.pragma library

// Looks: a name for a set of appearance options that go together (shape, surfaces, text, motion).
// The built-in ones are here; your own are in config (appearance.looks), made by `hi look save <name>`
// or Settings > Interface, and they travel with presets and profiles.

// The options a look holds (names under `appearance.`).
const keys = ["cornerScale", "surfaceStyle", "borderWidth", "textWeight", "letterSpacing", "motionStyle",
    "animationBounce", "density", "transparency", "transparencyLevel", "pressScale", "popupEffect", "sidebarEffect", "launcherEffect"];

const builtin = {
    "Soft": { icon: "spa", set: { cornerScale: 1, surfaceStyle: "tonal", borderWidth: -1, textWeight: "normal", letterSpacing: 0, motionStyle: "expressive", animationBounce: 1, density: "comfortable", popupEffect: "pop", sidebarEffect: "slide" } },
    "Glass": { icon: "blur_on", set: { cornerScale: 1.2, surfaceStyle: "glass", borderWidth: 1, textWeight: "normal", letterSpacing: 0.2, motionStyle: "smooth", animationBounce: 0.4, density: "comfortable", popupEffect: "drop", sidebarEffect: "fade" } },
    "Sharp": { icon: "crop_square", set: { cornerScale: 0.2, surfaceStyle: "flat", borderWidth: 2, textWeight: "medium", letterSpacing: 0.3, motionStyle: "snappy", animationBounce: 0, density: "compact", popupEffect: "fade", sidebarEffect: "slide" } },
    "Playful": { icon: "celebration", set: { cornerScale: 1.6, surfaceStyle: "tonal", borderWidth: -1, textWeight: "medium", letterSpacing: 0, motionStyle: "expressive", animationBounce: 1.8, density: "spacious", popupEffect: "drop", sidebarEffect: "pop" } },
    "Calm": { icon: "self_improvement", set: { cornerScale: 1, surfaceStyle: "tonal", borderWidth: 0, textWeight: "light", letterSpacing: 0.2, motionStyle: "smooth", animationBounce: 0, density: "spacious", popupEffect: "fade", sidebarEffect: "fade" } }
};

// A look's name: letters, digits, space, . _ - (it is a key in config).
function validName(name) {
    return typeof name === "string" && /^[\w .-]{1,40}$/.test(name) && name.trim() === name;
}

// Only the options a look may hold, with their values as they are.
function pick(options) {
    const out = {};
    for (const k of keys)
        if (options && options[k] !== undefined)
            out[k] = options[k];
    return out;
}

// All looks by name: the built-in ones, then yours (yours win on the same name).
function all(user) {
    const out = {};
    for (const n of Object.keys(builtin))
        out[n] = { icon: builtin[n].icon, set: builtin[n].set, builtin: true };
    for (const n of Object.keys(user || {}))
        if (validName(n))
            out[n] = { icon: "palette", set: pick(user[n]), builtin: false };
    return out;
}
