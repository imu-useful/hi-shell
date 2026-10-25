# Implementation Plan: HyprShell AI

## Stage 1: Basic Quickshell Setup & Top Bar
- [x] Create `shell.qml` with a top bar (PanelWindow).
- [x] Implement Workspaces indicator (using Quickshell.Hyprland).
- [x] Add Clock and active window title.
- [x] Test that it runs: `qs -c hi-shell`

## Stage 2: App Launcher
- [x] Create a floating Window for the App Launcher.
- [x] Bind a keybind (Super+Space via `hypr/hi-shell.lua`; Super+D is taken by maximize) to toggle the launcher.
- [x] Implement a search field that filters installed desktop applications (parse `/usr/share/applications`).
- [x] Add Material 3 styling (rounded corners, blur background).

## Stage 3: Claude AI Command Palette (The Core Feature)
- [x] Create a floating Window for the AI widget (Super+Y via `hypr/hi-shell.lua`; Super+A/Super+C are taken).
- [x] Add a text input and a "Send" button.
- [x] Use Quickshell's Process module to run `claude --print` with `--output-format stream-json` and stream the output live.
- [x] Display the output in a scrollable Material 3 card.
- [x] Implement a loading state (spinner) while Claude is thinking.

## Stage 4: Control Center & System Stats
- [x] Create a slide-out panel for the Control Center.
- [x] Add volume slider (Quickshell PipeWire service).
- [x] Add Wi-Fi/Bluetooth toggles (Quickshell Networking / Bluetooth modules).
- [x] Add CPU/RAM usage bars (`/proc/stat`, `/proc/meminfo`).

## Stage 5: Material 3 Theming (Matugen)
- [x] Write a Python script (`theme_updater.py`) that runs `matugen` to generate the palette from the wallpaper (`~/.local/state/hi-shell/colors.json`, loaded live by `common/Colors.qml` — no shell reload).
- [x] Re-run on wallpaper change (Hyprland has no such event; `common/Theme.qml` watches illogical-impulse's wallpaper path file) and on dark/light toggle.
- [x] Ensure all UI components use the dynamic colors.

## Stage 6: Build, Test, and README
- [x] Ensure the shell starts correctly on boot (`hypr/hi-shell.lua` runs `qs -c hi-shell` on `hyprland.start`).
- [x] Write a comprehensive `README.md` with installation instructions (dependencies: `quickshell`, `matugen`, `python`).
- [x] Push final code to GitHub.

---

# Phase 2: end4-pC-style shell

Goal: grow hi-shell into a full desktop shell in the style of [end4-pC](https://github.com/pctrade/end4-pC)
(an illogical-impulse fork): Material 3 Expressive shapes, a configurable bar, two sidebars, desktop widgets,
a wallpaper selector and a settings app. hi-shell stays **standalone** (it does not need `ii` running) and
everything is written from scratch: end4-pC is GPL-3.0 and its code is not copied here.

Out of scope for now: Niri support, community presets gallery, booru/anime, football, on-screen keyboard,
screen translator, translations other than en/ru.

## Stage 7: Foundation (config, design tokens, widget kit)
- [x] `common/Config.qml`: user config in `~/.config/hi-shell/config.json` (JSON, live reload, defaults merged, writes from the UI).
- [x] `common/Appearance.qml`: M3 Expressive tokens (shape scale, type scale, motion curves/durations, transparency), replaces `Style.qml`.
- [x] Extra M3 color roles (secondary, tertiary, surfaceContainerLow).
- [x] Material shapes (`common/shapes/`): cookie/clover/flower/blob polygons as `Shape` items, used by icons, clock, avatar, wallpaper frame.
- [x] Widget kit: `StyledPopup` (hover popups anchored to the bar), `Card`, `Chip`, `SegmentedButton`, `Switch`, `ListRow`, `StyledFlickable`.
- [x] `PanelLoader`: lazy-load panels so closed panels cost nothing.

## Stage 8: Core services
- [x] `services/Mpris.qml`: active player, controls, position (Quickshell.Services.Mpris).
- [x] `services/Weather.qml`: Open-Meteo (no API key), location from config or IP, cached.
- [x] `services/Battery.qml` (UPower), `services/Brightness.qml` (brightnessctl/ddcutil), `services/NetworkSpeed.qml` (`/proc/net/dev`).
- [x] `services/Notifications.qml`: notification server (Quickshell.Services.Notifications), history persisted to state.
- [x] `services/Tray.qml`, `services/Updates.qml` (`checkupdates`), resource usage extended with disk/GPU/temps.

## Stage 9: Bar v2
- [x] Configurable layout: `bar.left/center/right` lists of widget ids in config.json (UI editor in Stage 15).
- [x] Position top/bottom/left/right (vertical bar variant) and styles **Hug / Float / Islands / M3**.
- [x] Widgets: workspaces (dots + app icons), active window, media, resources, weather, clock/date, tray, system icons,
      util buttons (screenshot, color picker, dark mode, mic; wallpaper picker comes with Stage 14), network speed, battery, updates, keyboard layout, power, divider.
- [x] Hover/click popups per widget (resources, weather, battery, clock → existing calendar, media).
- [x] Bar cava visualizer (optional, `cava`).

## Stage 10: Notifications & OSD
- [ ] Notification popups (stacked, actions, inline reply, images, grouping by app, timeout progress).
- [ ] Do-not-disturb, unread count on the bar.
- [ ] OSD for volume / brightness / mic mute / keyboard layout.

## Stage 11: Right sidebar (replaces Control Center)
- [ ] Header: avatar, uptime, edit / reload / settings / power buttons.
- [ ] Quick toggles in two styles (Android-style pills and classic tiles), editable order: Wi-Fi, Bluetooth, dark mode,
      night light (hyprsunset), idle inhibitor, DND, mic, game mode, VPN, color picker, screenshot.
- [ ] Quick sliders: volume, brightness, mic; per-app volume and output device picker.
- [ ] Wi-Fi and Bluetooth sub-pages (scan, connect, password prompt).
- [ ] Bottom group: notification center, calendar (reuse the clock popup), to-do, timers.

## Stage 12: Left sidebar
- [ ] Home page: greeting card, media player with synced lyrics (LRCLIB), weather.
- [ ] AI chat: move the Claude palette here as a full chat (history, markdown + code blocks, model picker,
      Claude usage indicator); keep Super+Y as a quick palette.
- [ ] Translator page (`trans` / Google endpoint), clipboard history page (`cliphist`).

## Stage 13: Desktop widgets
- [ ] Background layer window with widgets: shape analog clock, big digital clock, weather, CPU/RAM/disk tiles,
      calendar, media + lyrics, user card (lock/settings/power), to-do, notes, world clock, focus/stopwatch/countdown timers,
      image frame.
- [ ] Edit mode: drag to place, snap to grid, per-widget on/off; positions saved in config.
- [ ] Full-width cava visualizer at the bottom (optional).

## Stage 14: Wallpapers & color schemes
- [ ] Wallpaper service of our own (no dependency on `ii`'s state file): set via `swww`, transitions, per-monitor.
- [ ] Wallpaper selector: local folders grid with thumbnails, random, online search (Wallhaven, Unsplash), resolution filter.
- [ ] Shaped wallpaper frame widget (cookie / blob mask over the wallpaper).
- [ ] matugen scheme variants (Tonal Spot, Content, Expressive, Fidelity, Fruit Salad, Monochrome, Neutral, Rainbow), auto mode,
      transparency toggle; optional GTK/Qt/terminal theming.

## Stage 15: Settings app
- [ ] Overlay panel (Super+Escape) with pages: Quick, General, Bar, Desktop, Interface, Services, Hyprland, About.
- [ ] Bar layout editor (chips per section, add/remove/reorder), positioning & styles.
- [ ] Hyprland page: displays (resolution, refresh, scale, rotation, position via `hyprctl`), input, gaps/rounding/blur.
- [ ] "Config file" button, settings search from the launcher (type `wallpaper`, `bar`, ...).

## Stage 16: Launcher v2 & system overlays
- [ ] Launcher prefixes: `<` keybinds list, `:` emoji, `=` calculator, `>` commands, `/` settings, clipboard.
- [ ] Workspace overview (live window previews, drag windows between workspaces).
- [ ] Session screen (lock, logout, suspend, reboot, shutdown), lock screen (or hyprlock integration), polkit agent.
- [ ] Dock (pinned + running apps, magnify), screen corners, region selector (screenshot / OCR / record).

## Stage 17: Polish & release
- [ ] First-run welcome, ru/en translations, presets export/import (config + wallpaper + scheme in one archive).
- [ ] Performance pass (lazy loading, idle CPU < 1%), multi-monitor test.
- [ ] README with screenshots, update `hypr/hi-shell.lua` with all new binds; push.
