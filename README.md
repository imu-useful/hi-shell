# hi-shell

A Quickshell-based desktop shell for Hyprland with Material 3 design and a built-in Claude AI palette.

- **Bar** — Hyprland workspaces, active window title, clock with a calendar popup, status button
- **App launcher** — fuzzy search over desktop entries
- **Claude AI palette** — type a prompt, the `claude` CLI answers in a Material 3 card (streamed, non-blocking)
- **Control center** — Wi-Fi, Bluetooth, dark/light mode, volume slider, CPU/RAM stats
- **Theming** — Material 3 palette generated from the wallpaper with matugen, reloaded live
- **Google Calendar** — month view with event dots and an agenda (optional)

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
| [Claude Code](https://docs.anthropic.com/en/docs/claude-code) | the AI palette (`claude` must be on `PATH` and signed in) |

```sh
paru -S quickshell-git matugen python ttf-material-symbols-variable-git
npm install -g @anthropic-ai/claude-code   # then run `claude` once to sign in
```

## Installation

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

3. Check `hyprctl configerrors` is empty and press <kbd>Super</kbd>+<kbd>Space</kbd>.

## Usage

| Shortcut | Action |
| --- | --- |
| <kbd>Super</kbd>+<kbd>Space</kbd> | App launcher |
| <kbd>Super</kbd>+<kbd>Y</kbd> | Claude AI palette |
| <kbd>Super</kbd>+<kbd>U</kbd> | Control center (also the status button on the bar) |
| click the clock | Calendar popup |

Change the keys in `hypr/hi-shell.lua`. Every panel can also be toggled over IPC, e.g. for your own binds or scripts:

```sh
qs -c hi-shell ipc call launcher toggle       # also: ai, controlcenter, calendar
qs -c hi-shell ipc call mpris playPause       # next, previous
qs -c hi-shell ipc call brightness increment  # decrement, set <percent>
qs -c hi-shell ipc call notifications toggleDnd   # clear
qs -c hi-shell ipc call weather refresh
qs -c hi-shell ipc call updates refresh       # count
qs -c hi-shell ipc call tray list             # item ids for tray.hidden
```

## Configuration

Settings live in `~/.config/hi-shell/config.json`, created with the defaults on first start.
Edits apply live, no restart needed. Sections:

- `appearance`: fonts, transparency, animation speed (`0` disables animations)
- `bar`: height, margin
- `weather`: `city` (or `latitude`/`longitude`; empty = locate by IP, which a VPN will skew), `imperial`, refresh interval
- `battery`: low / critical thresholds and warning notifications
- `notifications`: default popup timeout, history size
- `updates`: check interval, include AUR (via `yay` or `paru`)
- `tray.hidden`: tray item ids to hide
- `apps.terminal`: terminal for terminal apps and the system upgrade

## Notifications

hi-shell is a notification daemon. Only one daemon can run at a time: while another one
(illogical-impulse's `qs -c ii`, mako, dunst, ...) is running, hi-shell waits and takes over once it exits.
History is kept in `~/.local/state/hi-shell/notifications.json`.

## Theming

`common/Theme.qml` runs `services/theme_updater.py` at startup, whenever the wallpaper changes and when you switch dark/light
mode in the control center. The palette is written to `~/.local/state/hi-shell/colors.json` and picked up by
`common/Colors.qml` without restarting the shell. Only matugen's JSON output is used, so your other matugen templates are untouched.

The wallpaper is detected from illogical-impulse's state file, hyprpaper or swww. Hyprland has no wallpaper-change event,
so live updates currently rely on illogical-impulse's state file; with another wallpaper tool, tell the shell yourself:

```sh
qs -c hi-shell ipc call theme setWallpaper ~/Pictures/wall.png
qs -c hi-shell ipc call theme setMode light     # or: toggleMode, update
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

## Troubleshooting

- **Logs:** run `qs -c hi-shell` in a terminal, or `qs -c hi-shell log` for a running instance.
- **Two bars:** illogical-impulse starts its own shell (`qs -c ii`). Remove that line from
  `~/.config/hypr/hyprland/execs.lua` if you want hi-shell alone.
- **Shortcuts do nothing:** another bind may already use the key — check `hyprctl binds`.
- **No icons:** install `ttf-material-symbols-variable-git` and run `fc-cache -f`.
- **AI palette says `claude` was not found:** Hyprland's environment must have `claude` on `PATH`
  (e.g. `~/.local/bin`); set it in your Hyprland env config and log in again.

## Layout

```
shell.qml            entry point
modules/             Bar, Launcher, AIWidget, ControlCenter, CalendarPopup (+ subcomponents)
common/              singletons (Config, Appearance, Colors, Theme, ShellState, Calendar, SystemStats)
common/widgets/      widget kit (StyledText, MaterialIcon, Card, Chip, SegmentedButton, M3Switch, ListRow,
                     StyledPopup, StyledFlickable, PanelLoader, animations, buttons, slider)
common/shapes/       Material 3 Expressive shapes (MaterialShape, ShapeImage) with morphing
services/            QML services (Mpris, Weather, Battery, Brightness, NetworkSpeed, Notifications, Tray,
                     Updates, SystemStats, Calendar) and scripts: theme_updater.py (matugen), gcal.py
hypr/hi-shell.lua    Hyprland autostart, keybinds and layer rules
```

## License

See [LICENSE](LICENSE).
