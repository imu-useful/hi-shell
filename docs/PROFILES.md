# Presets, profiles and dotfiles

A **preset** is your look in one file: the config, the wallpaper and the colors. Safe to share: it leaves out
API keys, your location and this machine's monitor layout, and it carries nothing that can run code.

A **profile** is a preset for yourself: it also holds your rules, script widgets, QML widgets
(`~/.config/hi-shell/widgets`) and keybinds (`binds.lua`). That is code, so a profile is only applied with
an explicit OK (`--trust`, or "Apply with code" in Settings). Don't share a profile.

```sh
hi preset save work                    # a preset (Settings › About › Presets does the same)
hi preset save --profile work          # a profile: rules, scripts, widgets and keybinds too
hi preset list
hi preset diff work                     # what applying it would change (writes nothing)
hi preset load work                     # applies it; code in a profile is left out
hi preset load work --trust             # ... and brings the code
hi preset load work --only bar,dock     # only some parts
hi preset undo                          # the setup from before the last load is back
```

Parts for `--only`: any config section (`bar`, `dock`, `desktop`, `appearance`, `lock`, `sidebar`, `launcher`, ...)
and `colors`, `wallpaper`, `widgets`, `keybinds`. A name without a slash is a preset in
`~/.local/share/hi-shell/presets`; give a path for any other file.

Before a load, the files it may overwrite are copied to `~/.local/state/hi-shell/preset-backups` (the last 20).
`undo` puts back the config, keybinds and widget files (not the wallpaper or colors).

## Dotfiles in git

```sh
hi preset dump ~/dotfiles/hi-shell --profile    # a folder, not an archive
cd ~/dotfiles && git diff                       # one JSON file per config section, sorted, so only real changes show
hi preset restore ~/dotfiles/hi-shell --trust   # on another machine (with --only for a part)
```

The folder holds `config/<section>.json`, `colors.json`, `wallpaper.<ext>`, `widgets/*.qml` and `binds.lua`.
Dump again and it is rewritten in place, with the same bytes if nothing changed. Secrets (API keys, location, monitors)
are left out the same way as in a preset.

## Switching by itself

A rule can apply a preset when something happens (see [RULES.md](RULES.md)):

```json
{ "id": "desk", "when": { "screen": "HDMI-A-1" },
  "then": [ { "profile": "desk", "only": "bar,dock,desktop" } ],
  "else": [ { "profile": "undo" } ] }
```

`hi rules add monitor-profile` starts from this. Rules apply presets with trust, so keep `rules` out of what
they switch (`only`), or a preset could remove the rule that applied it.

## What it can't do

- It doesn't reload Hyprland: a profile's `binds.lua` is read at the next Hyprland reload.
- `undo` goes back one step at a time, in the order of the backups.
- Archives are limited to 50 widget files of 256 KB each.
