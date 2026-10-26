<div align="center">

# ✦ hi-shell

**A Material 3 Expressive desktop shell for Hyprland — with Claude AI built in.**

Built on [Quickshell](https://quickshell.org). Colors from your wallpaper, animations everywhere, English and Russian.

[![Arch Linux](https://img.shields.io/badge/Arch_Linux-1793D1?style=for-the-badge&logo=archlinux&logoColor=white)](https://archlinux.org)
[![Hyprland 0.56+](https://img.shields.io/badge/Hyprland-0.56%2B-58E1FF?style=for-the-badge&logo=hyprland&logoColor=black)](https://hyprland.org)
[![Quickshell](https://img.shields.io/badge/Quickshell-QML-41CD52?style=for-the-badge&logo=qt&logoColor=white)](https://quickshell.org)
[![Material You](https://img.shields.io/badge/Material_3-Expressive-7F67BE?style=for-the-badge&logo=materialdesign&logoColor=white)](https://m3.material.io)
<br>
[![License: GPL-2.0](https://img.shields.io/badge/License-GPL--2.0-blue?style=for-the-badge)](LICENSE)
[![Telegram chat](https://img.shields.io/badge/Telegram-tux__empire-26A5E4?style=for-the-badge&logo=telegram&logoColor=white)](https://t.me/tux_empire)

[Install](#installation) · [Shortcuts](#usage) · [Configuration](#configuration) · [Troubleshooting](#troubleshooting) · [Community](#community)

</div>

---

## Features

| | |
| --- | --- |
| 🧭 **Bar** | Configurable widgets (left / center / right), any screen edge, Hug / Float / Islands / M3 styles, hover popups for media, resources, weather, battery and updates, a live audio spectrum |
| 🚀 **App launcher** | Apps and settings, plus prefixes: `=` calculator, `>` run a command, `<` keybinds, `:` emoji, `;` clipboard, `/` settings |
| ✨ **Claude AI** | Quick palette (<kbd>Super</kbd>+<kbd>Y</kbd>) and a full chat in the left sidebar through the `claude` CLI: streamed answers, code blocks with copy buttons, model picker, token / cost usage, saved chats |
| 🪟 **Overlays** | Workspace overview with window previews (drag windows between workspaces), session screen, polkit dialog, region screenshot / OCR / recording, optional dock, rounded screen corners |
| ⬅️ **Left sidebar** | Greeting, now playing with synced lyrics, weather, Claude chat, translator, clipboard history with image thumbnails |
| ➡️ **Right sidebar** | Quick toggles (Android-style pills or classic buttons, editable), volume / brightness / mic, Wi-Fi and Bluetooth pages, per-app volume, notification center, calendar, to-do, focus / stopwatch / countdown timers |
| 🖼️ **Desktop** | Shape clock, big clock, weather, resources, calendar, media with lyrics, greeting, to-do, notes, world clock, timers, user card, image frame; audio visualizer; drag-to-place edit mode |
| 🎨 **Theming** | Wallpaper picker (local folders, Wallhaven, Unsplash), Material 3 palette from the wallpaper via matugen, scheme variants, light / dark / auto, shaped wallpaper frame |
| ⚙️ **Settings** | Every option in a settings app, Hyprland displays / gaps / blur / input included, searchable from the launcher |
| 🌍 **Languages** | English and Russian: the whole interface, dates and plural forms |
| 👋 **Welcome & presets** | A first-run setup, and presets that save your config, wallpaper and colors to one shareable file |
| 📅 **Google Calendar** | Month view with event dots and an agenda (optional) |

Animations run everywhere, yet the shell idles at about 1% CPU: hidden panels and disabled widgets aren't created,
and the audio spectrum is drawn by a single shader.

## Requirements

Arch Linux + Hyprland **0.56+** (the integration file uses the Lua config).

| Package | Used for |
| --- | --- |
| `quickshell-git` (AUR) | the shell itself (0.3+, with the Hyprland, Pipewire, Bluetooth and Networking modules) |
| `matugen` | Material 3 colors from the wallpaper |
| `python` | `services/theme_updater.py`, `services/gcal.py` (stdlib only, no pip packages) |
| `ttf-material-symbols-variable-git` (AUR) | icons (`Material Symbols Rounded`) |
| `pipewire`, `wireplumber` | volume control |
| `networkmanager` | Wi-Fi toggle |
| `bluez` | Bluetooth toggle |
| `upower` | battery status |
| `brightnessctl`, `ddcutil` (optional) | brightness of the built-in panel / external monitors |
| `pacman-contrib`, `yay` or `paru` (optional) | update count |
| `libnotify` | battery warnings (`notify-send`) |
| `hyprsunset` | night light (uses a running hyprsunset daemon, or starts one) |
| `cliphist`, `translate-shell` | clipboard history and translator in the left sidebar |
| `grim`, `slurp`, `wl-clipboard`, `hyprpicker`, `cava` (optional) | bar utility buttons and visualizer |
| `imagemagick`, `curl` | wallpaper thumbnails and downloads |
| `libqalculate` (`qalc`) | launcher calculator |
| `tesseract`, `tesseract-data-eng`, `tesseract-data-rus` (+ other languages), `wf-recorder` | region OCR and screen recording |
| `hyprlock` | lock screen (hi-shell's Lock runs it) |
| [Claude Code](https://docs.anthropic.com/en/docs/claude-code) | the AI palette (`claude` must be on `PATH` and signed in) |

```sh
paru -S quickshell-git matugen python ttf-material-symbols-variable-git
npm install -g @anthropic-ai/claude-code   # then run `claude` once to sign in
```

## Installation

### Quick install

```sh
git clone https://github.com/imu-useful/hi-shell.git ~/Projects/hi-shell
~/Projects/hi-shell/install.sh
```

or without cloning first (the repo goes to `~/.local/share/hi-shell/repo`):

```sh
bash <(curl -fsSL https://raw.githubusercontent.com/imu-useful/hi-shell/main/install.sh)
```

The installer:

1. installs the packages above with `pacman` and, for the AUR ones, `paru` or `yay` (asks first; `--no-deps` skips it)
2. links the repo to `~/.config/quickshell/hi-shell`
3. loads `hypr/hi-shell.lua` from your Hyprland config — `~/.config/hypr/custom/execs.lua` on illogical-impulse dots,
   `~/.config/hypr/hyprland.lua` otherwise (one marked line, with a backup of the file)
4. starts the shell and warns about other bars or notification daemons that are still running

Options: `--yes` (don't ask), `--no-deps`, `--no-start`. Then tap <kbd>Super</kbd>.

### Update

```sh
~/.config/quickshell/hi-shell/update.sh
```

Pulls the latest version (`git pull --ff-only`, so your local changes are never overwritten), shows what's new,
restarts the shell and reloads Hyprland when the keybinds changed.

### Uninstall

```sh
~/.config/quickshell/hi-shell/uninstall.sh            # keeps your settings and presets
~/.config/quickshell/hi-shell/uninstall.sh --purge    # also deletes settings, state and cache (asks first)
```

Stops the shell, removes the line from your Hyprland config and the link. Packages stay installed.

<details>
<summary>Manual installation</summary>

1. Clone the repo and link it where Quickshell looks for configs:

   ```sh
   git clone https://github.com/imu-useful/hi-shell.git ~/Projects/hi-shell
   mkdir -p ~/.config/quickshell
   ln -s ~/Projects/hi-shell ~/.config/quickshell/hi-shell
   ```

2. Load the Hyprland integration (autostart, keybinds, blur rules) from your config,
   e.g. `~/.config/hypr/custom/execs.lua` on illogical-impulse or `hyprland.lua` otherwise:

   ```lua
   dofile(os.getenv("HOME") .. "/.config/quickshell/hi-shell/hypr/hi-shell.lua")
   ```

   It starts `qs -c hi-shell` when Hyprland starts. To run it now without logging out:

   ```sh
   hyprctl reload && qs -c hi-shell -d
   ```

3. Check `hyprctl configerrors` is empty and tap <kbd>Super</kbd>.

</details>

## Usage

| Shortcut | Action |
| --- | --- |
| <kbd>Super</kbd> (tap) or <kbd>Super</kbd>+<kbd>Space</kbd> | App launcher |
| <kbd>Super</kbd>+<kbd>Y</kbd> | Claude AI palette |
| <kbd>Super</kbd>+<kbd>U</kbd> | Right sidebar (also the system icons on the bar) |
| <kbd>Super</kbd>+<kbd>Escape</kbd> | Settings |
| <kbd>Super</kbd>+<kbd>Tab</kbd> | Workspace overview |
| <kbd>Alt</kbd>+<kbd>Tab</kbd> | Switch windows: hold Alt, Tab / Shift+Tab through recent windows (with previews), release to switch; a quick tap goes to the previous window |
| <kbd>Super</kbd>+<kbd>Shift</kbd>+<kbd>S</kbd> | Region screenshot / OCR / recording (also the bar's screenshot button) |
| <kbd>Print</kbd> | Screenshot of the focused screen (saved to `~/Pictures/Screenshots` and copied) |
| <kbd>Ctrl</kbd>+<kbd>Print</kbd> | Screenshot of a region or window (saved and copied) |
| <kbd>Super</kbd>+<kbd>Shift</kbd>+<kbd>X</kbd> | Copy text from a region (OCR) |
| <kbd>Super</kbd>+<kbd>Shift</kbd>+<kbd>T</kbd> | Translate text from a region (OCR into the sidebar translator) |
| <kbd>Super</kbd>+<kbd>Shift</kbd>+<kbd>R</kbd> | Record a region (press again to stop) |
| <kbd>Super</kbd>+<kbd>V</kbd> | Clipboard history (Enter copies) |
| <kbd>Super</kbd>+<kbd>.</kbd> | Emoji picker |
| <kbd>Ctrl</kbd>+<kbd>Alt</kbd>+<kbd>Delete</kbd> | Session screen |
| Display key (<kbd>Fn</kbd>+<kbd>F10</kbd> on Lenovo, `XF86Display`) | Display mode: this screen only, duplicate, extend left / right, second screen only; press again for the next, Enter to apply |
| bar power button | Session screen (lock, log out, suspend, reboot, power off) |
| <kbd>Super</kbd>+<kbd>R</kbd> | Wallpaper picker |
| <kbd>Super</kbd>+<kbd>Z</kbd> | Left sidebar (also right click on the bar's ✦ button) |
| click the clock | Calendar popup |
| click the system icons | Right sidebar (scroll there to change the volume) |
| right click the desktop | Edit desktop widgets: drag them (edges and centers snap to other widgets and the screen, with guide lines), toggle them in the toolbar; Esc or Done to finish |
| hover a bar widget | Details popup (media controls, resources, weather forecast, battery, updates) |
| scroll | Every slider (volume, brightness, mic, app volumes, track position, settings); on the bar: system icons = volume, battery = brightness, media = player volume, keyboard layout = switch, workspaces = previous / next; the calendar scrolls through months |

Change the keys in `hypr/hi-shell.lua`. Every panel can also be toggled over IPC, e.g. for your own binds or scripts:

```sh
qs -c hi-shell ipc call launcher toggle       # also: ai, sidebarRight, calendar
qs -c hi-shell ipc call sidebarRight openTab todo     # notifications, calendar, todo, timers
qs -c hi-shell ipc call sidebarRight openPage wifi    # bluetooth, audio
qs -c hi-shell ipc call todo add "Buy milk"           # list
qs -c hi-shell ipc call sidebarLeft openTab claude    # home, claude, translator, clipboard
qs -c hi-shell ipc call ai ask "What's a good name for a cat?"
qs -c hi-shell ipc call claude chats                 # deleteChat <id>, newChat
qs -c hi-shell ipc call desktop toggleEdit            # edit, done, resetLayout
qs -c hi-shell ipc call launcher search "=2+2"        # open the launcher with text typed
qs -c hi-shell ipc call region screenshot             # ocr, translate, record, stop, cancel, fullscreen
qs -c hi-shell ipc call session lock                  # logout, suspend, hibernate, reboot, poweroff, toggleScreen
qs -c hi-shell ipc call overview toggle
qs -c hi-shell ipc call switcher next                # prev, commit, cancel (Alt+Tab)
qs -c hi-shell ipc call bar toggle                   # show, hide
qs -c hi-shell ipc call display set mirror           # internal, left, right, external; toggle, next (the display key)
qs -c hi-shell ipc call settings open hyprland        # toggle, close; pages: quick general bar desktop interface services hyprland about
qs -c hi-shell ipc call mpris playPause       # next, previous
qs -c hi-shell ipc call brightness increment  # decrement, set <percent>
qs -c hi-shell ipc call notifications toggleDnd   # clear, list, dismiss <uid>
qs -c hi-shell ipc call weather refresh
qs -c hi-shell ipc call updates refresh       # count
qs -c hi-shell ipc call tray list             # item ids for tray.hidden
qs -c hi-shell ipc call presets save "Autumn"         # load <path>, list
qs -c hi-shell ipc call welcome open                  # the first-run welcome again
```

## Configuration

Use the settings panel (<kbd>Super</kbd>+<kbd>Escape</kbd>), or edit `~/.config/hi-shell/config.json` (created with
the defaults on first start; edits apply live). The Hyprland page applies changes at once and keeps them in
`~/.config/hi-shell/hyprland.lua`, which `hypr/hi-shell.lua` loads at startup; "Reset Hyprland overrides" removes them.
Sections:

- `language`: `auto` (from `$LANG`), `en` or `ru`
- `appearance`: fonts, transparency, animation speed (`0` disables animations), matugen `scheme`, `autoMode`
- `wallpapers`: folders, download folder, `unsplashKey` / `wallhavenKey`, desktop `frame` shape, `frameDance` (the frame turns and pulses to the music)
- `bar`: `position` (top, bottom, left, right), `style` (hug, float, islands, m3), height, margin, and the widget
  lists `left` / `center` / `right`. Widgets: `launcher`, `workspaces`, `activeWindow`, `media`, `resources`, `clock`,
  `weather`, `tray`, `systemIcons`, `notifications`, `utilButtons`, `networkSpeed`, `battery`, `updates`, `keyboardLayout`, `power`,
  `visualizer` (needs `cava`), `divider`. Per-widget options: `bar.workspaces`, `bar.clock`, `bar.media`,
  `bar.resources`, `bar.utilButtons`, `bar.updates`; `bar.media.spinArt` spins the cover art like a record while playing (on by default)
- `sidebar`: `quickToggles.style` (android, classic) and `quickToggles.shown` (order; also editable with the ✎ button
  in the sidebar), night light temperature
- `desktop`: `focusMode` (with windows open: sharp wallpaper, widgets and frame hidden; on by default), `coverMode` (the playing track's cover instead of the wallpaper, colors included; also a quick toggle and
  `qs -c hi-shell ipc call coverMode toggle`), draw the `wallpaper`, show `widgets`, `monitor` for them (empty = first screen), `layout` (written by edit
  mode), `worldClocks` (IANA zones), `image` for the image frame, bottom `visualizer`
- `ai.model`: claude CLI model alias (empty = CLI default, `opus`, `sonnet`, `haiku`; also the picker in the chat)
- `translator`: target language and the quick-pick list
- `clipboard.watch`: start `wl-paste --watch cliphist store` with the shell (skipped if already running)
- `weather`: `city` (or `latitude`/`longitude`; empty = locate by IP, which a VPN will skew), `imperial`, refresh interval
- `battery`: low / critical thresholds and warning notifications
- `notifications`: default popup timeout, history size
- `updates`: check interval, include AUR (via `yay` or `paru`)
- `tray.hidden`: tray item ids to hide
- `dock`: enabled (off by default), auto-hide, magnify, icon size, pinned app ids
- `capture`: OCR languages (`auto` = every installed tesseract language, or e.g. `eng+rus`), record audio
- `appearance.screenCorners`: rounded screen corner radius (0 = off)
- `apps.terminal`: terminal for terminal apps and the system upgrade

## Lock screen

hi-shell locks with hyprlock, using a lock screen it generates from its own look in
`~/.config/hi-shell/hyprlock.conf`: the current wallpaper blurred, a big clock in the palette's primary color, the date
and a greeting in the interface language, your avatar (`~/.face`), a Material password field, now playing, battery and
keyboard layout. It follows wallpaper, palette, font and language changes. Lock from the session menu or
`qs -c hi-shell ipc call session lock`; for idle and suspend, point hypridle at it:

```ini
$lock_cmd = pidof hyprlock || hyprlock -c ~/.config/hi-shell/hyprlock.conf || hyprlock
```

## Notifications

hi-shell is a notification daemon. Only one daemon can run at a time: while another one
(illogical-impulse's `qs -c ii`, mako, dunst, ...) is running, hi-shell waits and takes over once it exits.
History is kept in `~/.local/state/hi-shell/notifications.json`.
With no notifications, the notification center shows Chrome's T-rex: click it to play (Space / Up / click to jump, Down
to duck; the best score is kept in `~/.local/state/hi-shell/dino.txt`).

Popups appear in the corner next to the bar: click a popup for the app's default action (or to expand it),
use its buttons or inline reply, swipe it sideways or press × to dismiss. Hovering pauses its timeout.
The bell in the bar shows the unread count: left click marks all read, right click toggles do not disturb
(critical notifications still show).

Volume, mic mute, brightness and keyboard layout changes show a short indicator under the bar, whatever
made the change (keys, `wpctl`, `brightnessctl`, ...).

## Wallpapers & theming

hi-shell draws the wallpaper itself (desktop layer) and generates the Material 3 palette from it with matugen.
Open the picker with <kbd>Super</kbd>+<kbd>R</kbd> or the wallpaper button on the bar:

- **Local**: every image in `wallpapers.directories` (default `~/Pictures/Wallpapers`), with thumbnails cached in
  `~/.cache/hi-shell/thumbnails` (the first scan of a big folder takes a minute; the grid fills in as it goes)
- **Online**: Wallhaven search with a minimum resolution (1080p / 2K / 4K) and paging; picks are downloaded to
  `wallpapers.downloadDirectory`. Unsplash appears too once `wallpapers.unsplashKey` is set
  (free key from [unsplash.com/developers](https://unsplash.com/developers))
- **Random**, matugen **scheme** (Tonal Spot, Content, Expressive, Fidelity, Fruit Salad, Monochrome, Neutral, Rainbow,
  Vibrant), **Light / Dark / Auto** (auto = light between sunrise and sunset), transparency, and a **frame**: the
  wallpaper inside a Material shape over a blurred copy of itself

The current wallpaper is kept in `~/.local/state/hi-shell/wallpaper.txt`, the palette in
`~/.local/state/hi-shell/colors.json`. Dark / light also sets GTK's `color-scheme` (`appearance.gtkColorScheme`).

```sh
qs -c hi-shell ipc call wallpaper set ~/Pictures/wall.png    # random, get, toggleSelector
qs -c hi-shell ipc call theme setMode light                  # toggleMode, setScheme expressive, update
```

## Google Calendar

Click the clock in the bar to open the calendar popup (month view + upcoming events).
hi-shell reads your calendars through the Google Calendar API (read-only). You need your own OAuth client once:

1. Open [Google Cloud Console](https://console.cloud.google.com/) and create a project (e.g. `hi-shell`).
2. **APIs & Services → Library** → search **Google Calendar API** → **Enable**.
3. **Google Auth Platform → Branding**: set an app name and your email (user type **External**).
4. **Audience**: add your Google account under **Test users**.
5. **Clients → Create client** → application type **Desktop app** → create, then **Download JSON**.
6. Save the file as `~/.config/hi-shell/google-client.json`.
7. Click the clock → **Connect Google Calendar** (or run `python3 services/gcal.py auth`) and allow access in the browser.

The token is stored in `~/.local/state/hi-shell/google-token.json` (mode 600). Sign out with `python3 services/gcal.py logout`.

**Weekly re-sign-in:** while the app's publishing status is *Testing*, Google expires the sign-in after 7 days and the popup asks you to reconnect.
To avoid that, click **Publish app** under **Audience**. Google then shows an "unverified app" warning on sign-in
(it's your own app; choose *Advanced → Go to hi-shell*).

Try the UI without a Google account: `HI_SHELL_GCAL_DEMO=1 qs -c hi-shell`.

## Language

The interface is in English or Russian: Settings → General → Language, or `"language"` in the config.
`auto` picks Russian when `$LANG` starts with `ru`. Dates, month and day names follow the chosen language too.

Translations live in `translations/<code>.json`, keyed by the English text. Plural forms are arrays
(`["%1 задача", "%1 задачи", "%1 задач"]`). To add a language, copy `ru.json`, translate the values and add the
code to `available` in `common/Translation.qml`.

## Welcome & presets

On the first start a short welcome sets the language, wallpaper, light / dark mode and bar style, shows the main
shortcuts and lists optional programs that are missing. It won't show again (the marker is
`~/.local/state/hi-shell/welcome-done`); reopen it with `qs -c hi-shell ipc call welcome open`.

A preset is one `.tar.gz` with your config, wallpaper and color scheme. Save and apply them in Settings → About;
they're kept in `~/.local/share/hi-shell/presets`. Presets leave out API keys, your location and the monitor layout,
and applying one keeps yours. The wallpaper is copied to `~/Pictures/Wallpapers/presets` unless you already have
the same file.

## Troubleshooting

- **Logs:** run `qs -c hi-shell` in a terminal, or `qs -c hi-shell log` for a running instance.
- **Rendering:** `run.sh` (what Hyprland starts) uses Vulkan when a Vulkan driver is installed, which costs less CPU
  per frame than OpenGL. To use OpenGL: `qs -c hi-shell kill; QSG_RHI_BACKEND=opengl ~/.config/quickshell/hi-shell/run.sh -d`.
- **Developing:** start with `HI_SHELL_DEV=1 qs -c hi-shell` to reload on file changes (off by default: the current
  Quickshell build can crash while reloading).
- **Screen doesn't lock on idle:** if your `hypridle.conf` came with illogical-impulse, its `lock_cmd`
  (`hyprctl dispatch global quickshell:lock & pidof qs quickshell hyprlock || hyprlock`) never starts hyprlock
  while hi-shell runs. Use the `lock_cmd` from [Lock screen](#lock-screen).
- **Two bars:** illogical-impulse starts its own shell (`qs -c ii`). Remove that line from
  `~/.config/hypr/hyprland/execs.lua` if you want hi-shell alone.
- **Shortcuts do nothing:** another bind may already use the key — check `hyprctl binds`.
- **No icons:** install `ttf-material-symbols-variable-git` and run `fc-cache -f`.
- **AI palette says `claude` was not found:** Hyprland's environment must have `claude` on `PATH`
  (e.g. `~/.local/bin`); set it in your Hyprland env config and log in again.

## Layout

```
shell.qml            entry point
modules/             Bar, Desktop, DesktopVisualizer, DisplayMode, Settings, Welcome, WindowSwitcher, WallpaperSelector, Overview, SessionScreen, PolkitDialog, RegionSelector, Dock, Launcher, AIWidget, SidebarLeft, SidebarRight, CalendarPopup, NotificationPopups, OnScreenDisplay (+ subcomponents)
common/              singletons (Config, Appearance, Colors, Theme, ShellState, Translation, Paths)
common/widgets/      widget kit (StyledText, MaterialIcon, Card, Chip, SegmentedButton, M3Switch, ListRow,
                     StyledPopup, StyledFlickable, PanelLoader, Spectrum, animations, buttons, slider)
common/widgets/shaders/  spectrum.frag (+ compiled .qsb) for the audio spectrum
common/shapes/       Material 3 Expressive shapes (MaterialShape, ShapeImage) with morphing
services/            QML services (Mpris, Weather, Battery, Brightness, NetworkSpeed, Notifications, Tray,
                     Updates, SystemStats, Calendar, Presets) and scripts: theme_updater.py (matugen), gcal.py,
                     presets.py
translations/        interface translations (ru.json)
hypr/hi-shell.lua    Hyprland autostart, keybinds and layer rules
run.sh               start the shell (Vulkan rendering when available)
install.sh           install packages, link the repo, hook into Hyprland
update.sh            pull and restart
uninstall.sh         unhook and unlink (--purge: settings too)
```

## Community

Questions, screenshots of your setup, ideas and bug reports — join the Telegram chat:
**[t.me/tux_empire](https://t.me/tux_empire)**

Bugs can also go to [GitHub issues](https://github.com/imu-useful/hi-shell/issues).

## License

GPL-2.0 — see [LICENSE](LICENSE).
