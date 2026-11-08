# Keybinds and IPC commands

Everything in hi-shell can be driven from outside with Quickshell's IPC:

```sh
qs -c hi-shell ipc call <target> <function> [args...]
hi-shell ipc <target> <function> [args...]      # the same, shorter
qs -c hi-shell ipc show                          # list every target and function the running shell knows
```

Keybinds are just Hyprland binds that run one of these commands. The shipped ones are in
`~/.config/hypr/hi-shell/keybinds.lua`. `hi-shell keybinds [word]` prints them.

## Making your own binds

Add a line to your own Hyprland config (for example `~/.config/hypr/custom/keybinds.lua`, so `update.sh`
never touches it), or edit `keybinds.lua` itself:

```lua
-- keys, what to run, a description (shown by the launcher on "<" and by `hyprctl binds`)
hl.bind("SUPER + B", hl.dsp.exec_cmd("qs -c hi-shell ipc call bar toggle"), { description = "Hide / show the bar" })

-- a function with an argument
hl.bind("SUPER + SHIFT + W", hl.dsp.exec_cmd("qs -c hi-shell ipc call display set mirror"))

-- text with spaces: quote it inside the command
hl.bind("SUPER + N", hl.dsp.exec_cmd("qs -c hi-shell ipc call todo add 'Buy milk'"))
```

Useful bind options: `locked = true` (works on the lock screen), `release = true` (fire on key release),
`repeating = true` (hold to repeat, handy for brightness), `description = "..."`.

If a key is already bound by something else (an old shell's binds, say), unbind it first:
`hl.unbind("SUPER + B")`.

Notes:

- Calls go to the running shell. If it is not running, `ipc call` fails, so for keys you need even then
  (screenshots, lock) the shipped binds go through `hypr/hi-shell/fallback.sh`.
- Functions marked **returns** print a value to stdout, which is useful in scripts, not in binds.
- Arguments are plain strings; an `int` argument must be a number, a `bool` is `true` / `false`.
- Many targets come in a `toggle` / `open` / `close` trio that behaves the same way everywhere:
  `toggle` flips, `open` opens (does nothing if already open), `close` closes.

## Panels and windows

### launcher: the search / app launcher

| Function | What it does |
|---|---|
| `toggle` | Open the launcher, or close it if open |
| `open` | Open it |
| `close` | Close it |
| `search <text>` | Open it with text already typed. Prefixes switch the mode: `;` clipboard history, `:` emoji, `=` calculator (`=2+2`), `<` the keybinds list |

### appgrid: the full-screen list of every app

`toggle`, `open`, `close`. The dock's first button does the same.

### overview: workspace overview

`toggle`, `open`, `close`.

### sidebarLeft: the left sidebar

| Function | What it does |
|---|---|
| `toggle` / `open` / `close` | As usual |
| `openTab <tab>` | Open on a tab: `home`, `claude`, `translator`, `clipboard`. `claude` falls back to `home` when the Claude tab is disabled |

### sidebarRight: the right sidebar

| Function | What it does |
|---|---|
| `toggle` / `open` / `close` | As usual |
| `openTab <tab>` | Open on a tab: `notifications`, `calendar`, `todo`, `timers` |
| `openPage <page>` | Open a sub-page: `wifi`, `bluetooth`, `audio` |

### ai: the Claude AI palette

| Function | What it does |
|---|---|
| `toggle` / `open` / `close` | As usual (`open` does nothing if the AI widget is disabled) |
| `ask <prompt>` | Open the palette and send the prompt right away |
| `reset` | Start a fresh conversation in the palette |

### claude: the saved Claude chats (left sidebar tab)

| Function | What it does |
|---|---|
| `chats` | **returns** one `id<TAB>title` line per saved chat, newest first |
| `deleteChat <id>` | Delete that chat |
| `newChat` | Start a new chat |

### settings: the Settings window

| Function | What it does |
|---|---|
| `toggle` / `close` | As usual |
| `open [page]` | Open, optionally on a page: `quick`, `general`, `bar`, `desktop`, `interface`, `services`, `hyprland`, `about` |

### processes: the process manager

`toggle`, `open`, `close`. Search, sort by CPU / RAM, end or force-kill. (If you configured a custom
process manager program, `toggle` and `open` start that instead.)

### calendar: the calendar popup

`toggle`, `open`, `close`.

### weatherDetails: the weather popup

`toggle`, `open`, `close`. Current conditions, next 24 hours, 7 days.

### switcher: the Alt+Tab window switcher

| Function | What it does |
|---|---|
| `next` | Open it (or step) to the next window |
| `prev` | Step to the previous window |
| `commit` | Switch to the chosen window and close the switcher |
| `cancel` | Close without switching |

Typical setup: `Alt+Tab` → `next`, `Alt+Shift+Tab` → `prev`, and a **release** bind on `Alt_L` / `Alt_R` →
`commit` (see the top of `keybinds.lua`).

### display: the display mode picker (internal / external screens)

| Function | What it does |
|---|---|
| `toggle` | Open or close the picker |
| `next` | What the display key does: open the picker, then step through the modes on each press |
| `set <mode>` | Apply a mode directly: `internal`, `mirror`, `left`, `right`, `external` |

### displays: screen info

| Function | What it does |
|---|---|
| `screens` | **returns** the screens the shell has windows for, one `name WxH+X+Y` per line |

### desktop: the desktop widgets layer

| Function | What it does |
|---|---|
| `edit` | Enter widget edit mode (move / resize / add widgets) |
| `done` | Leave edit mode |
| `toggleEdit` | Flip edit mode |
| `resetLayout` | Put every desktop widget back to its default place |

### island: the bar's island (notifications / media / etc.)

| Function | What it does |
|---|---|
| `cycle` | Switch to the next thing the island shows |
| `open` | Open the island |
| `expand` | Expand or collapse it |

### bar: the top bar

| Function | What it does |
|---|---|
| `toggle` / `show` / `hide` | Hide or show the bar |
| `status` | **returns** JSON about what decides whether the bar shows (for bug reports) |

### welcome / updateDialog

| Target | Function | What it does |
|---|---|---|
| `welcome` | `open` | Show the welcome tour from the first step |
| `welcome` | `close` | Finish and close it |
| `updateDialog` | `preview` | Show the "update available" dialog as a preview |

## Session and screen

### session: power menu and actions

| Function | What it does |
|---|---|
| `lock` | Lock the screen |
| `logout` | Log out |
| `suspend` | Suspend |
| `hibernate` | Hibernate |
| `reboot` | Reboot |
| `poweroff` | Shut down |
| `toggleScreen` | Open or close the full-screen session menu |

### lock: the lock screen itself

| Function | What it does |
|---|---|
| `lock` | Lock |
| `unlock` | Unlock without a password. Only reachable from a script on the same session, so it is for testing |
| `isLocked` | **returns** `true` / `false` |

### boot: reboot into another OS / boot entry

| Function | What it does |
|---|---|
| `list` | **returns** `id<TAB>title` for each boot entry |
| `reboot <id>` | Reboot straight into that entry |

### region: screenshots, OCR, recording

| Function | What it does |
|---|---|
| `screenshot` | Select a region; saved to `~/Pictures/Screenshots` and the clipboard |
| `ocr` | Select a region; its text goes to the clipboard |
| `translate` | Select a region; OCR it and open the text in the translator |
| `record` | Select a region and record it; if a recording is running, stop it |
| `stop` | Stop the running recording |
| `cancel` | Cancel the selection |
| `fullscreen` | Screenshot of the whole focused screen straight to clipboard + file, no selection |

Region selection can't be shown over a lock screen, which is why the `Print` bind goes through
`fallback.sh screen` (a whole-screen shot) when locked.

### brightness

| Function | What it does |
|---|---|
| `increment` | Brighter, on the focused screen |
| `decrement` | Dimmer |
| `set <percent>` | Set it, `0` to `100` |

### mpris: the media player

| Function | What it does |
|---|---|
| `playPause` | Play / pause |
| `next` | Next track |
| `previous` | Previous track |
| `shuffle` | Toggle shuffle |
| `repeat` | Cycle repeat: off → playlist → track |

### notifications

| Function | What it does |
|---|---|
| `toggleDnd` | Do Not Disturb on / off |
| `clear` | Clear all notifications |
| `list` | **returns** `uid<TAB>app<TAB>summary` per notification, newest first |
| `dismiss <uid>` | Dismiss one |

## Modes

### presentation: presentation mode

`toggle`, `on`, `off`, `status` (**returns** `{"active": ...}`).

### coverMode

`toggle`, `on`, `off`. Turns the cover-mode desktop option on or off.

### viewing: viewing mode

| Function | What it does |
|---|---|
| `toggle` | Toggle viewing mode manually |
| `status` | **returns** JSON `{active, manual, fullscreen}` |

### focus: Focus Mode

| Function | What it does |
|---|---|
| `settings` | Open the Focus Mode window (not while a session runs) |
| `openTab <tab>` | Open it on a tab: `timer`, `wallpaper`, `lists`, `profiles`, `todo`, `exit` |
| `closeSettings` | Close the window |
| `start` | Start a session with the active profile |
| `stop` | Stop it (only in Manual exit mode, like the Stop button) |
| `abort` | Emergency exit, whatever the exit condition is |
| `status` | **returns** `inactive`, or `active<TAB>profile<TAB>phase cycle/total<TAB>seconds left` |
| `profile <id>` | Pick the active profile: `study`, `work`, or the id of your own |
| `current` | **returns** `id<TAB>name` of the active profile |
| `addTask <text>` | Add a to-do task picked for the session |
| `addProfile <name> <icon>` | **returns** the id of a new blank profile (`icon` is a Material Symbols name; pass `""` for the default) |

Focus Mode blocks sites through `/etc/hosts` (see the README for how to undo a leftover block).

### focusStats

| Function | What it does |
|---|---|
| `summary` | **returns** focus time, tasks, streak, sessions, achievements |
| `resetTour` | Show the Focus Mode introduction again next time the window opens |

### screentime

| Function | What it does |
|---|---|
| `today` | **returns** JSON of today's per-app usage |
| `limit <program> <minutes>` | Daily limit for an app (its name or command); `0` removes the limit |
| `limits` | **returns** the limits as JSON |

### waitmode: the screen cover

`waitmode` exists twice. The main shell (`qs -c hi-shell`) starts and stops it; the cover itself is a separate
Quickshell instance (`qs -p wait-mode`).

| Function | Instance | What it does |
|---|---|---|
| `start` | hi-shell | Cover the screens |
| `stop` | hi-shell | End it |
| `toggle` | hi-shell | Start or stop |
| `status` | hi-shell | **returns** `on` / `off` |
| `bypass <on> <seconds>` | wait-mode | Make the cover invisible and click-through for a while (tests) |
| `stop` / `status` | wait-mode | Quit the cover / **returns** its state |

Panic exit while it is running: **Ctrl+Alt+Shift+Esc**.

## Data and appearance

### theme

| Function | What it does |
|---|---|
| `update` | Regenerate the colours from the wallpaper (forced) |
| `setMode <mode>` | `dark` or `light` |
| `toggleMode` | Flip dark / light |
| `setScheme <scheme>` | `tonal-spot`, `content`, `expressive`, `fidelity`, `fruit-salad`, `monochrome`, `neutral`, `rainbow`, `vibrant` |

### wallpaper

| Function | What it does |
|---|---|
| `set <path>` | Set a wallpaper (image or video file) |
| `random` | Pick a random one from your wallpaper folder |
| `get` | **returns** the current wallpaper path |
| `status` | **returns** JSON `{current, kind, live, still}` |
| `toggleSelector` | Open or close the wallpaper picker |

### presets: settings presets

| Function | What it does |
|---|---|
| `save [name]` | Save the current settings as a preset (no name: date and time) |
| `load <path>` | Load a preset file |
| `list` | **returns** the preset paths, one per line |

### todo

| Function | What it does |
|---|---|
| `add <text>` | Add a task |
| `toggle <number>` | Mark done / not done; the number is its position in `list`, from 1 |
| `list` | **returns** `[ ] text` / `[x] text` per line |

### weather / updates / tray

| Target | Function | What it does |
|---|---|---|
| `weather` | `refresh` | Fetch the weather again |
| `updates` | `refresh` | Check for updates |
| `updates` | `updateShell` | Update hi-shell itself |
| `updates` | `count` | **returns** how many updates are pending |
| `tray` | `list` | **returns** `id<TAB>title` per tray item (use the ids for the `tray.hidden` option) |

## Recipes

```lua
-- Media keys
hl.bind("XF86AudioPlay",  hl.dsp.exec_cmd("qs -c hi-shell ipc call mpris playPause"), { locked = true })
hl.bind("XF86AudioNext",  hl.dsp.exec_cmd("qs -c hi-shell ipc call mpris next"),      { locked = true })
hl.bind("XF86AudioPrev",  hl.dsp.exec_cmd("qs -c hi-shell ipc call mpris previous"),  { locked = true })

-- Brightness keys (hold to repeat)
hl.bind("XF86MonBrightnessUp",   hl.dsp.exec_cmd("qs -c hi-shell ipc call brightness increment"), { locked = true, repeating = true })
hl.bind("XF86MonBrightnessDown", hl.dsp.exec_cmd("qs -c hi-shell ipc call brightness decrement"), { locked = true, repeating = true })

-- Lock, power menu, do not disturb, focus session
hl.bind("SUPER + L",         hl.dsp.exec_cmd("qs -c hi-shell ipc call session lock"))
hl.bind("SUPER + Backspace", hl.dsp.exec_cmd("qs -c hi-shell ipc call session toggleScreen"))
hl.bind("SUPER + D",         hl.dsp.exec_cmd("qs -c hi-shell ipc call notifications toggleDnd"))
hl.bind("SUPER + F",         hl.dsp.exec_cmd("qs -c hi-shell ipc call focus start"))

-- Open the launcher straight in a mode
hl.bind("SUPER + C", hl.dsp.exec_cmd("qs -c hi-shell ipc call launcher search '='"), { description = "Calculator" })
```

In a shell script, the functions that return a value are handy:

```sh
qs -c hi-shell ipc call wallpaper get
qs -c hi-shell ipc call notifications list | wc -l
qs -c hi-shell ipc call lock isLocked
```
