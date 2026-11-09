# Your own bar widgets

Two ways, no rebuild and no restart:

1. **A script widget**: a command, with the output shown in the bar. No QML.
2. **A QML widget**: a file in `~/.config/hi-shell/widgets/`.

Either goes into a bar list like any built-in widget: Settings › Bar, `hi bar edit` (drag it on), or
`hi bar add <id> <position> <widget>`.

## Script widgets

```sh
hi script temp 'sensors | grep -m1 Package | tr -s " " | cut -d" " -f4' 10 device_thermostat '{}'
```

`hi script <name> '<command>' [seconds] [icon] [template]` makes `script#<name>`; add `script#temp` to a bar.
It is the same as writing this under `bar.instances` in `config.json`:

```json
"script#temp": {
  "command": "sensors | grep -m1 Package | tr -s ' ' | cut -d' ' -f4",
  "interval": 10,
  "icon": "device_thermostat",
  "template": "{}",
  "click": "kitty -e btop"
}
```

| Option | Meaning |
| --- | --- |
| `command` | Run with `sh -c` every `interval` seconds; the first line of stdout is the text |
| `interval` | Seconds between runs (default 5, `0` = once) |
| `template` | The text; `{}` is the command's output (default `{}`) |
| `icon` | A [Material Symbols](https://fonts.google.com/icons) name |
| `color` | `primary`, `secondary`, `tertiary`, `error` or `#rrggbb` |
| `json` | `true`: the command prints `{"text": "...", "icon": "...", "color": "..."}` (what it prints wins over the options) |
| `click`, `rightClick`, `middleClick` | Commands run on a click |
| `scrollUp`, `scrollDown` | Commands run on scrolling over the widget |
| `hideWhenEmpty` | Hide while the command prints nothing (default `true`) |

## QML widgets

```sh
hi widgets new clockwork       # makes ~/.config/hi-shell/widgets/clockwork.qml from a template
hi widgets list                # each file and whether it loaded
```

The file name (letters, digits and `_`, starting with a letter) is the widget's name; use `clockwork` in a bar
list, or `clockwork#work` for a copy with options of its own. Names of built-in widgets can't be used. A saved file is
loaded again within two seconds. If it has an error, you get a notification, the error is listed in Settings › Bar
and `hi widgets list`, and the last version that worked stays in the bar.

The root of the file is a `BarWidget`:

```qml
import QtQuick
import qs.common
import qs.common.widgets
import qs.modules.bar

BarWidget {
    shown: true            // false hides it (it stays in the list)
    clickable: true
    contentWidth: label.implicitWidth
    contentHeight: label.implicitHeight

    StyledText {
        id: label
        anchors.centerIn: parent
        text: root.pick("label", "Hi")
    }
    onClicked: mouse => console.log("clicked", mouse.button)
}
```

What a widget can use:

- **`BarWidget`** (`qs.modules.bar`): `shown`, `clickable`, `scrollable`, `active`, `padding`, `contentWidth`,
  `contentHeight`, `pill` (draw the pill behind it), signals `clicked(mouse)`, `scrolled(steps)`, `pressedDown()`,
  `pressedUp()`; read-only `vertical` (the bar is on a side), `thickness`, `hovered`, `bar` (its screen and style),
  `popupEdge`, `instance` (the options of this copy) and `pick(key, fallback)` (an option of the copy, else the fallback).
- **`qs.common`**: `Config` (`Config.options.*`), `Colors` (`Colors.m3primary`, ...), `Appearance` (sizes, fonts, radii:
  `Appearance.font.size.normal`, `Appearance.rounding.medium`), `Translation.tr("...")`, `ShellState`.
- **`qs.common.widgets`**: `StyledText`, `MaterialIcon`, `IconButton`, `Chip`, `M3Button`, `CircularProgress`, `ColorAnim`,
  `SpatialAnim` and the rest of the folder; **`Poll`** runs a command every N seconds (`Poll { command: "date"; interval: 5 }`,
  then `poll.output`).
- **`qs.services`**: the shell's services, e.g. `Mpris`, `Battery`, `Notifications`, `SystemStats`, `Weather`, `Claude`, `Theme`.
- Anything from `Quickshell`, `Quickshell.Io` (`Process`, ...) and `Quickshell.Hyprland`.

A copy gets its options from `bar.instances`:

```sh
hi bar instance 'clockwork#work' '{"label": "Work"}'
```

## Limits

- Widgets live in a bar; a widget can't add its own window yet.
- A QML widget has the same access as the shell itself: only use files you trust.
- Put the widget's files straight in the folder (no subfolders); other files it needs go next to it and are loaded
  by relative path.
