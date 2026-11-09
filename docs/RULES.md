# Rules

"When this is true, do that." A rule watches a condition; when it turns true its actions run, and when it turns
false what it changed is put back.

```sh
hi rules templates            # ready-made rules
hi rules add battery-saver    # power saving while on battery below 30%
hi rules                      # your rules: on / off, active now
hi rules edit my-rule         # the rule as JSON in $EDITOR (a new id starts from a skeleton)
hi rules off my-rule          # also: on, rm, show, facts (what conditions can see), check
```

Also in Settings › Rules. Rules live in `config.json` under `rules`; `rulesEnabled: false` stops them all.

```json
{
  "id": "docked",
  "name": "A dock on every screen with a second screen",
  "enabled": true,
  "when": { "screenCount": { "atLeast": 2 } },
  "then": [ { "set": "dock.monitors", "value": ["*"] } ],
  "else": []
}
```

## Conditions

One key each; combine them with `all`, `any` and `not`.

| Condition | True when |
| --- | --- |
| `{ "battery": "discharging" }` | on battery and not charging (also `"charging"`, `"full"`, `"plugged"`) |
| `{ "battery": { "below": 30, "above": 10 } }` | the charge is in that range (needs a battery) |
| `{ "fullscreen": true }` | a window is fullscreen on some screen |
| `{ "screen": "HDMI-A-1" }` | that screen is connected (`hyprctl monitors`) |
| `{ "screenCount": { "atLeast": 2 } }` | how many screens (`atLeast`, `atMost`, `below`, `above`, or a number) |
| `{ "time": ["22:00", "07:00"] }` | now is in that range, past midnight too |
| `{ "weekday": [1, 2, 3, 4, 5] }` | today is one of these (0 = Sunday) |
| `{ "app": "firefox" }` | the focused window's class contains this (any case) |
| `{ "appOpen": "steam_app" }` | some window's class contains this |
| `{ "workspace": 3 }` | the focused workspace |
| `{ "dark": true }` | dark mode is on |
| `{ "playing": true }` | media is playing |
| `{ "command": "ping -c1 -W1 192.168.1.1" }` | the command exits with 0 (run every 30 s) |

## Actions

| Action | Does |
| --- | --- |
| `{ "set": "bar.height", "value": 30 }` | sets a config option; put back when the rule ends, unless you changed it meanwhile or the action has `"keep": true` |
| `{ "ipc": "theme setMode dark" }` | `qs ipc call <target> <function> [args]` (`hi ipc` lists them) |
| `{ "run": "notify-send hi" }` | a shell command |
| `{ "notify": "Battery saver is on" }` | a notification |

`then` runs when the condition turns true, `else` when it turns false (after the options are put back). A rule that
is already true when the shell starts runs its `then` once; which rules were on is kept in
`~/.local/state/hi-shell/rules.json`, so a restart in the middle of a rule still puts things back later.

## Good to know

- Conditions are checked a moment after something changes (windows, screens, battery, ...) and the time once a
  minute, so a rule reacts within a second or so, a time range within 30 seconds.
- `ipc` and `run` actions are not undone: pair them with an `else` that does the opposite.
- Rules can run commands, so a preset you import never brings its rules (nor its script widgets).
