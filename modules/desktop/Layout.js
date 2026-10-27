.pragma library

// Default desktop widget layout (all off; turned on in edit mode or Settings): x / y are fractions of the screen (top-left corner).
const defaults = {
    shapeClock: { enabled: false, x: 0.03, y: 0.07 },
    greeting: { enabled: false, x: 0.03, y: 0.37 },
    media: { enabled: false, x: 0.03, y: 0.49 },
    digitalClock: { enabled: false, x: 0.39, y: 0.06 },
    weather: { enabled: false, x: 0.75, y: 0.06 },
    resources: { enabled: false, x: 0.75, y: 0.21 },
    calendar: { enabled: false, x: 0.75, y: 0.36 },
    todo: { enabled: false, x: 0.75, y: 0.56 },
    worldClock: { enabled: false, x: 0.55, y: 0.30 },
    notes: { enabled: false, x: 0.55, y: 0.56 },
    timers: { enabled: false, x: 0.30, y: 0.76 },
    userCard: { enabled: false, x: 0.03, y: 0.76 },
    imageFrame: { enabled: false, x: 0.40, y: 0.36 }
};

const names = {
    shapeClock: "Shape clock",
    greeting: "Greeting",
    media: "Media",
    digitalClock: "Digital clock",
    weather: "Weather",
    resources: "Resources",
    calendar: "Calendar",
    todo: "To-do",
    worldClock: "World clock",
    notes: "Notes",
    timers: "Timers",
    userCard: "User",
    imageFrame: "Image"
};

const ids = Object.keys(defaults);

function entry(layout, id) {
    return Object.assign({}, defaults[id], (layout ?? {})[id] ?? {});
}
