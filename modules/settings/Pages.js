.pragma library

// The groups the settings pages are sorted into, in the order the navigation shows them.
const groups = [
    { id: "personalize", title: "Personalization" },
    { id: "desktop", title: "Desktop" },
    { id: "system", title: "System & apps" },
    { id: "habits", title: "Habits & automation" },
    { id: "shell", title: "Shell" }
];

// Settings pages and the words that find them from the launcher. Pages of a group sit
// together here, in the order the navigation shows them; a page with no group (Overview)
// is shown above the groups.
const pages = [
    { id: "home", title: "Overview", icon: "home", group: "", description: "Wallpaper, colors, quick switches and every page", keywords: "overview home start quick wallpaper colors color scheme palette dark light mode auto transparency matugen theme power saving do not disturb dnd night light game mode advanced" },
    { id: "style", title: "Style", icon: "palette", group: "personalize", description: "Looks, palette, shape, surfaces, fonts and app themes", keywords: "style looks look palette seed color contrast shape size density corners roundness text size screen corners surfaces tonal glass flat outline border transparency opacity blur cover context menu fonts font weight letter spacing app themes gtk neovim icons themed" },
    { id: "motion", title: "Motion", icon: "animation", group: "personalize", description: "Animation speed and feel, effects and the startup greeting", keywords: "motion animation animations speed spring bounce overshoot ripple press squeeze color fade popup effect launcher effect sidebar effect panels bar notifications greeting startup welcome" },
    { id: "wallpaper", title: "Wallpaper", icon: "wallpaper", group: "personalize", description: "Wallpaper, slideshow, the frame and online wallpapers", keywords: "wallpaper wallpapers background draw live video gif slideshow random download folder cover mode clean desktop frame shape dance music beat image unsplash wallhaven api key folders online" },
    { id: "lock", title: "Lock screen", icon: "lock", group: "personalize", description: "What the lock screen shows and when it locks", keywords: "lock screen clock date greeting avatar password battery keyboard layout caps lock now playing blur brightness wallpaper" },
    { id: "sounds", title: "Sounds", icon: "volume_up", group: "personalize", description: "The sound pack and the events that play a sound", keywords: "sounds sound pack miui samsung one ui notification timer battery charger screenshot volume mute event effects" },
    { id: "bar", title: "Bar", icon: "toolbar", group: "desktop", description: "Which bars, where they sit and what is on them", keywords: "bar layout widgets position top bottom left right style hug float islands m3 height workspaces clock date format resources util buttons media dynamic island notifications music privacy camera microphone fullscreen" },
    { id: "desktop", title: "Desktop", icon: "desktop_windows", group: "desktop", description: "Screens, desktop widgets and world clocks", keywords: "desktop screens screen monitor per screen widgets edit layout arrange clock seconds visualizer cava wave progress player world clock time zones" },
    { id: "dock", title: "Dock", icon: "dock_to_bottom", group: "desktop", description: "Where the dock is, when it shows and how it looks", keywords: "dock position auto hide autohide empty workspace apps button running pinned indicators dots magnify zoom gap spacing corner radius edge icon size" },
    { id: "panels", title: "Sidebars & launcher", icon: "side_navigation", group: "desktop", description: "What the sidebars show and what the launcher searches", keywords: "sidebar sidebars quick toggles sliders tabs notifications calendar todo timers tiles per page game night light temperature launcher search sources prefixes calculator emoji clipboard files" },
    { id: "hyprland", title: "Hyprland", icon: "dvr", group: "system", description: "Displays, look of windows, mouse and touchpad", keywords: "hyprland display displays monitor mode duplicate mirror extend projector second screen resolution refresh rate scale orientation rotate position gaps border rounding blur shadow animations input mouse sensitivity touchpad natural scroll focus" },
    { id: "notifications", title: "Notifications", icon: "notifications", group: "system", description: "Popups, do not disturb and the history", keywords: "notifications notification popup timeout dnd do not disturb focus hold history size" },
    { id: "power", title: "Power & battery", icon: "battery_saver", group: "system", description: "Power saving and low battery warnings", keywords: "power saving battery low critical warnings energy laptop" },
    { id: "services", title: "Services", icon: "settings_suggest", group: "system", description: "Weather, updates, screen capture and Spotify", keywords: "weather city location latitude longitude fahrenheit updates aur check screen capture recording sound ocr tesseract spotify client id" },
    { id: "autostart", title: "Autostart", icon: "rocket_launch", group: "system", description: "Programs that start with the session", keywords: "autostart startup start login boot exec exec-once run command commands program programs app apps launch hyprland" },
    // The Keybinds page (KeybindsPage.qml) is switched off for now: put its entry back here to show it.
    // { id: "keybinds", title: "Keybinds", icon: "keyboard", keywords: "keybinds keybindings shortcuts hotkeys keys bind binds key super ctrl alt shift remap rebind hyprland" },
    { id: "defaultapps", title: "Defaults", icon: "open_in_new", group: "system", description: "Apps that open links, files and the task manager", keywords: "task manager ctrl shift escape btop htop system monitor processes defaults default apps applications browser web file manager email images video music audio pdf text editor terminal open with mime xdg" },
    { id: "screentime", title: "Screen time", icon: "hourglass_top", group: "habits", description: "How long you use your apps, and daily limits", keywords: "screen time usage used apps app limit limits minutes hours today week statistics focus time spent" },
    { id: "rules", title: "Rules", icon: "rule", group: "habits", description: "When something is true, change settings or run a command", keywords: "rules automation when then condition battery fullscreen time night monitor connected app open script trigger power saving dark mode schedule" },
    { id: "modes", title: "Modes", icon: "co_present", group: "habits", description: "Presentation mode, and viewing mode for fullscreen video", keywords: "modes mode presentation screen share sharing hold notifications keep awake night light hide bar widgets viewing video fullscreen movie" },
    { id: "contentfilter", title: "Content filter", icon: "shield", group: "habits", description: "Block adult sites and close tabs by words in their title", keywords: "content filter adult sites block hosts tabs words keywords browser title close" },
    { id: "general", title: "General", icon: "apps", group: "shell", description: "Language, the AI chat, translator and clipboard", keywords: "language russian english terminal claude ai model translator languages clipboard history cliphist" },
    { id: "about", title: "About", icon: "info", group: "shell", description: "Version, updates, presets and credits", keywords: "about version quickshell source credits presets preset export import backup share" }
];

// Tabs of the pages that have them: the page shows one tab at a time (the first when none
// is picked). `options`: the option paths (or prefixes ending in ".") on that tab, so a
// search hit opens the right one; options not listed are on the first tab.
const tabs = {
    bar: [
        { id: "layout", title: "Layout", icon: "view_quilt", options: [] },
        { id: "widgets", title: "Widgets", icon: "widgets", options: ["bar.workspaces.", "bar.clock.", "bar.media.", "bar.resources.", "bar.utilButtons.", "bar.updates.", "bar.instances"] },
        { id: "own", title: "Your own widgets", icon: "extension", options: [] },
        { id: "island", title: "Dynamic Island", icon: "circle_notifications", options: ["bar.island."] }
    ]
};

function tabsOf(pageId) {
    return tabs[resolve(pageId)] ?? [];
}

// The tab of a page an option is on ("" for a page without tabs).
function tabFor(pageId, path) {
    const list = tabsOf(pageId);
    const hit = list.find(t => t.options.some(o => o.endsWith(".") ? path.startsWith(o) : path === o));
    return (hit ?? list[0])?.id ?? "";
}

// The pages of a group, in order.
function inGroup(groupId) {
    return pages.filter(p => p.group === groupId);
}

// Old page ids that still open a page (`hi settings quick`, saved state).
const aliases = { quick: "home", interface: "style" };

function resolve(id) {
    return aliases[id] ?? id;
}

// The page with this id (or an old id of it), or null.
function find(id) {
    const real = resolve(id);
    return pages.find(p => p.id === real) ?? null;
}

function group(id) {
    return groups.find(g => g.id === id) ?? null;
}

// Pages matching every word of the query (title, group or keywords, in English or
// through tr, the interface language), best first.
function search(query, tr = s => s) {
    const words = query.toLowerCase().trim().split(/\s+/).filter(w => w);
    if (!words.length)
        return [];
    return pages.map(p => {
        const g = group(p.group)?.title ?? "";
        const hay = `${p.title} ${g} ${p.keywords} ${tr(p.title)} ${tr(g)} ${tr(p.keywords)}`.toLowerCase();
        if (!words.every(w => hay.includes(w)))
            return null;
        const starts = p.title.toLowerCase().startsWith(words[0]) || tr(p.title).toLowerCase().startsWith(words[0]);
        return { page: p, score: starts ? 0 : 1 };
    }).filter(r => r).sort((a, b) => a.score - b.score).map(r => r.page);
}
