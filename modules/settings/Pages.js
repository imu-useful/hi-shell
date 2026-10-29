.pragma library

// Settings pages and the words that find them from the launcher.
const pages = [
    { id: "quick", title: "Quick", icon: "tune", keywords: "wallpaper colors color scheme palette dark light mode auto transparency matugen theme" },
    { id: "general", title: "General", icon: "apps", keywords: "language russian english terminal claude ai model translator languages clipboard history cliphist" },
    { id: "bar", title: "Bar", icon: "toolbar", keywords: "bar layout widgets position top bottom left right style hug float islands m3 height workspaces clock date format resources util buttons media" },
    { id: "desktop", title: "Desktop", icon: "desktop_windows", keywords: "desktop widgets wallpaper draw frame shape cover album art focus blur hide music dance pulse beat world clock time zones visualizer cava edit layout image" },
    { id: "lock", title: "Lock screen", icon: "lock", keywords: "lock screen clock date greeting avatar password battery keyboard layout caps lock now playing blur brightness wallpaper" },
    { id: "interface", title: "Interface", icon: "palette", keywords: "fonts font animation speed motion transparency opacity sidebar quick toggles night light temperature" },
    { id: "services", title: "Services", icon: "settings_suggest", keywords: "weather city location fahrenheit battery warnings low critical notifications timeout dnd do not disturb updates aur unsplash wallhaven api key folders" },
    { id: "hyprland", title: "Hyprland", icon: "dvr", keywords: "hyprland display displays monitor mode duplicate mirror extend projector second screen resolution refresh rate scale orientation rotate position gaps border rounding blur shadow animations input mouse sensitivity touchpad natural scroll focus" },
    { id: "autostart", title: "Autostart", icon: "rocket_launch", keywords: "autostart startup start login boot exec exec-once run command commands program programs app apps launch hyprland" },
    // The Keybinds page (KeybindsPage.qml) is switched off for now: put its entry back here to show it.
    // { id: "keybinds", title: "Keybinds", icon: "keyboard", keywords: "keybinds keybindings shortcuts hotkeys keys bind binds key super ctrl alt shift remap rebind hyprland" },
    { id: "about", title: "About", icon: "info", keywords: "about version quickshell source credits presets preset export import backup share" }
];

// Pages matching every word of the query (title or keywords, in English or
// through tr, the interface language), best first.
function search(query, tr = s => s) {
    const words = query.toLowerCase().trim().split(/\s+/).filter(w => w);
    if (!words.length)
        return [];
    return pages.map(p => {
        const hay = `${p.title} ${p.keywords} ${tr(p.title)} ${tr(p.keywords)}`.toLowerCase();
        if (!words.every(w => hay.includes(w)))
            return null;
        const starts = p.title.toLowerCase().startsWith(words[0]) || tr(p.title).toLowerCase().startsWith(words[0]);
        return { page: p, score: starts ? 0 : 1 };
    }).filter(r => r).sort((a, b) => a.score - b.score).map(r => r.page);
}
