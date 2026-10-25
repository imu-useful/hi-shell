-- hi-shell Hyprland integration (Lua config, Hyprland 0.56+).
-- Load it from your config (e.g. ~/.config/hypr/custom/execs.lua):
--   dofile(os.getenv("HOME") .. "/.config/quickshell/hi-shell/hypr/hi-shell.lua")

-- Keybinds go through IPC rather than Hyprland global shortcuts: Quickshell
-- (0.3.2) segfaults on exit while destroying GlobalShortcut objects.

-- hi-shell owns its keys: drop other binds on the same keys first (e.g. a previous
-- shell's binds that would also fire), then bind the IPC call.
local function bind(keys, call, description)
    if hl.unbind then
        hl.unbind(keys)
    end
    hl.bind(keys, hl.dsp.exec_cmd("qs -c hi-shell ipc call " .. call), { description = "hi-shell: " .. description })
end

-- Start the shell with Hyprland
hl.on("hyprland.start", function()
    hl.exec_cmd("qs -c hi-shell")
end)

-- App launcher (Super+D is commonly bound to maximize, so Super+Space is the default)
bind("SUPER + Space", "launcher toggle", "Toggle app launcher")

-- Tap Super alone for the launcher too. The release bind only fires when Super was the
-- last key pressed (so Super+1 etc. don't open it); the launcher also ignores holds
-- longer than half a second (Super + mouse to move or resize a window).
for _, key in ipairs({ "SUPER + Super_L", "SUPER + Super_R" }) do
    if hl.unbind then
        hl.unbind(key)
    end
    hl.bind(key, hl.dsp.exec_cmd("qs -c hi-shell ipc call launcher superDown"), { transparent = true })
    hl.bind(key, hl.dsp.exec_cmd("qs -c hi-shell ipc call launcher superUp"),
        { release = true, transparent = true, description = "hi-shell: App launcher (tap Super)" })
end

-- Blur behind the translucent launcher card
hl.layer_rule({ match = { namespace = "hi-shell-launcher" }, blur = true })
hl.layer_rule({ match = { namespace = "hi-shell-launcher" }, ignore_alpha = 0.3 })

-- Claude AI palette (Super+A / Super+C are commonly taken; Super+Y is free by default)
bind("SUPER + Y", "ai toggle", "Toggle Claude AI palette")
hl.layer_rule({ match = { namespace = "hi-shell-ai" }, blur = true })
hl.layer_rule({ match = { namespace = "hi-shell-ai" }, ignore_alpha = 0.3 })

-- Left sidebar: home / Claude chat / translator / clipboard
bind("SUPER + Z", "sidebarLeft toggle", "Toggle left sidebar")

-- Launcher modes: clipboard history and emoji (Enter copies)
bind("SUPER + V", "launcher search ';'", "Clipboard history")
bind("SUPER + Period", "launcher search ':'", "Emoji")

-- Workspace overview, session menu, region capture
bind("SUPER + Tab", "overview toggle", "Workspace overview")

-- Alt+Tab: hold Alt, Tab / Shift+Tab through recent windows, release Alt to switch.
bind("ALT + Tab", "switcher next", "Switch windows")
bind("ALT + SHIFT + Tab", "switcher prev", "Switch windows (back)")
for _, key in ipairs({ "Alt_L", "Alt_R" }) do
    hl.bind(key, hl.dsp.exec_cmd("qs -c hi-shell ipc call switcher commit"),
        { release = true, ignore_mods = true, transparent = true, description = "hi-shell: Switch to the chosen window" })
end
hl.layer_rule({ match = { namespace = "hi-shell-switcher" }, blur = true })
hl.layer_rule({ match = { namespace = "hi-shell-switcher" }, ignore_alpha = 0.3 })
bind("CTRL + ALT + Delete", "session toggleScreen", "Session menu")
bind("SUPER + SHIFT + S", "region screenshot", "Screenshot / OCR / record a region")
-- Screenshots always go to ~/Pictures/Screenshots and the clipboard.
bind("Print", "region fullscreen", "Screenshot of the screen (file + clipboard)")
bind("CTRL + Print", "region screenshot", "Screenshot of a region or window (file + clipboard)")
bind("SUPER + SHIFT + X", "region ocr", "Copy text from a region (OCR)")
bind("SUPER + SHIFT + T", "region translate", "Translate text from a region")
bind("SUPER + SHIFT + R", "region record", "Record a region (again to stop)")
hl.layer_rule({ match = { namespace = "hi-shell-overview" }, blur = true })
hl.layer_rule({ match = { namespace = "hi-shell-overview" }, ignore_alpha = 0.3 })
hl.layer_rule({ match = { namespace = "hi-shell-session" }, blur = true })
hl.layer_rule({ match = { namespace = "hi-shell-session" }, ignore_alpha = 0.3 })
hl.layer_rule({ match = { namespace = "hi-shell-polkit" }, blur = true })
hl.layer_rule({ match = { namespace = "hi-shell-dock" }, blur = true })
hl.layer_rule({ match = { namespace = "hi-shell-dock" }, ignore_alpha = 0.3 })
-- The region selector shows a frozen screenshot; no animation so it doesn't flicker.
hl.layer_rule({ match = { namespace = "hi-shell-region" }, no_anim = true })

-- Settings
bind("SUPER + Escape", "settings toggle", "Settings")
hl.layer_rule({ match = { namespace = "hi-shell-settings" }, blur = true })
hl.layer_rule({ match = { namespace = "hi-shell-settings" }, ignore_alpha = 0.3 })

-- Wallpaper picker (local + online, color scheme, frame)
bind("SUPER + R", "wallpaper toggleSelector", "Wallpaper picker")
hl.layer_rule({ match = { namespace = "hi-shell-wallpapers" }, blur = true })
hl.layer_rule({ match = { namespace = "hi-shell-wallpapers" }, ignore_alpha = 0.3 })

-- Right sidebar (also opens from the system icons on the bar)
bind("SUPER + U", "sidebarRight toggle", "Toggle right sidebar")
hl.layer_rule({ match = { namespace = "hi-shell-sidebar" }, blur = true })
hl.layer_rule({ match = { namespace = "hi-shell-sidebar" }, ignore_alpha = 0.3 })

-- Calendar popup (opens from the bar clock)
hl.layer_rule({ match = { namespace = "hi-shell-calendar" }, blur = true })
hl.layer_rule({ match = { namespace = "hi-shell-calendar" }, ignore_alpha = 0.3 })

-- Bar (translucent styles blur what's behind; ignore_alpha keeps fully transparent parts unblurred)
hl.layer_rule({ match = { namespace = "hi-shell-bar" }, blur = true })
hl.layer_rule({ match = { namespace = "hi-shell-bar" }, ignore_alpha = 0.3 })

-- Notification popups and on-screen indicators
hl.layer_rule({ match = { namespace = "hi-shell-notifications" }, blur = true })
hl.layer_rule({ match = { namespace = "hi-shell-notifications" }, ignore_alpha = 0.3 })
hl.layer_rule({ match = { namespace = "hi-shell-osd" }, blur = true })
hl.layer_rule({ match = { namespace = "hi-shell-osd" }, ignore_alpha = 0.3 })


-- Monitor and look & feel overrides made in hi-shell's settings app (generated file).
local overrides = os.getenv("HOME") .. "/.config/hi-shell/hyprland.lua"
local f = io.open(overrides, "r")
if f then
    f:close()
    dofile(overrides)
end
