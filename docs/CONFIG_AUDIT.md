# Config audit

214 options in `common/ConfigOptions.qml`.

## Options without a control in the settings app (46)

| Option | Type | Default |
| --- | --- | --- |
| `appearance.restartOnIconTheme` | `bool` | `true` |
| `appearance.fonts.icon` | `string` | `"Material Symbols Rounded"` |
| `appearance.colorOverrides` | `var` | `({})` |
| `appearance.gtkColorScheme` | `bool` | `true` |
| `bar.height` | `int` | `40` |
| `bar.margin` | `int` | `6` |
| `bar.left` | `list<string>` | `["launcher", "activeWindow"]` |
| `bar.center` | `list<string>` | `["resources", "media", "workspaces", "clock", "utilButtons", "weather"]` |
| `bar.right` | `list<string>` | `["tray", "keyboardLayout", "battery", "notifications", "systemIcons", "power"]` |
| `sidebar.quickToggles.shown` | `list<string>` | `["wifi", "bluetooth", "darkMode", "nightLight", "dnd", "keepAwake", "mic", "gameMode", "focusSession", "colorPicker", "screenshot"]` |
| `wallpapers.downloadDirectory` | `string` | `"~/Pictures/Wallpapers/online"` |
| `wallpapers.frameSize` | `real` | `0.62` |
| `desktop.layouts` | `var` | `({})` |
| `desktop.toolbar.x` | `real` | `-1` |
| `desktop.toolbar.y` | `real` | `-1` |
| `idle.manage` | `bool` | `false` |
| `idle.lockMin` | `int` | `5` |
| `idle.screenOffMin` | `int` | `10` |
| `idle.suspendMin` | `int` | `15` |
| `idle.separateBattery` | `bool` | `false` |
| `idle.batLockMin` | `int` | `2` |
| `idle.batScreenOffMin` | `int` | `3` |
| `idle.batSuspendMin` | `int` | `5` |
| `lock.clock` | `bool` | `true` |
| `lock.date` | `bool` | `true` |
| `lock.greeting` | `bool` | `true` |
| `lock.nowPlaying` | `bool` | `true` |
| `lock.battery` | `bool` | `true` |
| `lock.keyboardLayout` | `bool` | `true` |
| `lock.capsLockHint` | `bool` | `true` |
| `powerSaving.saved` | `var` | `({})` |
| `ai.model` | `string` | `""` |
| `ai.keys` | `var` | `({})` |
| `ai.openrouterKey` | `string` | `""` |
| `ai.openrouterModel` | `string` | `""` |
| `translator.target` | `string` | `"en"` |
| `weather.latitude` | `real` | `0` |
| `weather.longitude` | `real` | `0` |
| `focus.breathing` | `bool` | `true` |
| `notifications.holdInFocus` | `bool` | `true` |
| `tray.hidden` | `list<string>` | `[]` |
| `hyprland.monitors` | `var` | `({})` |
| `hyprland.options` | `var` | `({})` |
| `dock.pinned` | `list<string>` | `["firefox", "kitty", "org.gnome.Nautilus"]` |
| `capture.ocrLanguages` | `string` | `"auto"` |
| `capture.recordSound` | `string` | `"off"` |

## Options not referenced anywhere (13)

- `appearance.fonts.icon`
- `appearance.colorOverrides`
- `appearance.gtkColorScheme`
- `bar.left`
- `bar.center`
- `bar.right`
- `lock.clock`
- `lock.date`
- `lock.greeting`
- `lock.nowPlaying`
- `lock.battery`
- `lock.keyboardLayout`
- `lock.capsLockHint`

## Hardcoded values in modules/ and common/widgets/

124 colors, 76 durations, 105 radii, 37 font sizes

| File | Total | Colors | Durations | Radii | Font sizes |
| --- | --- | --- | --- | --- | --- |
| `modules/secret/HyperOS.qml` | 39 | 33 | 6 | 0 | 0 |
| `modules/secret/Story.qml` | 27 | 26 | 1 | 0 | 0 |
| `modules/secret/Mania.qml` | 24 | 17 | 1 | 1 | 5 |
| `modules/settings/HandLogo.qml` | 20 | 0 | 20 | 0 | 0 |
| `modules/secret/Nyan.qml` | 19 | 19 | 0 | 0 | 0 |
| `modules/secret/OneUI.qml` | 13 | 11 | 2 | 0 | 0 |
| `modules/Welcome.qml` | 9 | 0 | 7 | 1 | 1 |
| `common/widgets/AnimatedLogo.qml` | 7 | 0 | 7 | 0 | 0 |
| `modules/sidebar/QuickToggles.qml` | 5 | 0 | 0 | 5 | 0 |
| `modules/settings/AboutPage.qml` | 5 | 1 | 4 | 0 | 0 |
| `modules/secret/Disco.qml` | 5 | 5 | 0 | 0 | 0 |
| `modules/launcher/AppItem.qml` | 5 | 0 | 1 | 1 | 3 |
| `modules/dock/DockItem.qml` | 5 | 0 | 4 | 1 | 0 |
| `modules/desktop/DesktopWidget.qml` | 5 | 0 | 1 | 4 | 0 |
| `modules/bar/PrivacyPill.qml` | 5 | 5 | 0 | 0 | 0 |
