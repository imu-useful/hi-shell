-- hi-shell Hyprland integration (Lua config, Hyprland 0.56+).
-- install.sh copies this file to ~/.config/hypr/hi-shell.lua and loads it from your config:
--   dofile(os.getenv("HOME") .. "/.config/hypr/hi-shell.lua")
-- It's yours to edit (change a key, add a rule); update.sh doesn't overwrite your changes,
-- it puts the new version next to the file as hi-shell.lua.new when the two differ.
--
-- Sections: Startup · Keybinds · Window rules · Layer rules · Settings overrides · Wait Mode

------------------------------------------------------------------------------
-- Startup
------------------------------------------------------------------------------

hl.on("hyprland.start", function()
    hl.exec_cmd(os.getenv("HOME") .. "/.config/quickshell/hi-shell/run.sh")
end)

------------------------------------------------------------------------------
-- Keybinds
------------------------------------------------------------------------------
-- They go through IPC rather than Hyprland global shortcuts: Quickshell (0.3.2)
-- segfaults on exit while destroying GlobalShortcut objects.

-- hi-shell owns its keys: drop other binds on the same keys first (e.g. a previous
-- shell's binds that would also fire), then bind the IPC call.
local function bind(keys, call, description)
    if hl.unbind then
        hl.unbind(keys)
    end
    hl.bind(keys, hl.dsp.exec_cmd("qs -c hi-shell ipc call " .. call), { description = "hi-shell: " .. description })
end

-- Launcher (Super+D is commonly bound to maximize, so Super+Space is the default)
bind("SUPER + Space", "launcher toggle", "Toggle app launcher")
bind("SUPER + V", "launcher search ';'", "Clipboard history")
bind("SUPER + Period", "launcher search ':'", "Emoji")

-- Panels
bind("SUPER + Y", "ai toggle", "Toggle Claude AI palette") -- Super+A / Super+C are commonly taken
bind("SUPER + Z", "sidebarLeft toggle", "Toggle left sidebar")
bind("SUPER + U", "sidebarRight toggle", "Toggle right sidebar")
bind("SUPER + Tab", "overview toggle", "Workspace overview")
bind("SUPER + R", "wallpaper toggleSelector", "Wallpaper picker")
bind("SUPER + Escape", "settings toggle", "Settings")
bind("CTRL + ALT + Delete", "session toggleScreen", "Session menu")
-- The laptop's display key (Fn+F10 on Lenovo): display mode picker, again for the next mode.
bind("XF86Display", "display next", "Display mode")

-- Alt+Tab: hold Alt, Tab / Shift+Tab through recent windows, release Alt to switch.
bind("ALT + Tab", "switcher next", "Switch windows")
bind("ALT + SHIFT + Tab", "switcher prev", "Switch windows (back)")
for _, key in ipairs({ "Alt_L", "Alt_R" }) do
    hl.bind(key, hl.dsp.exec_cmd("qs -c hi-shell ipc call switcher commit"),
        { release = true, ignore_mods = true, transparent = true, description = "hi-shell: Switch to the chosen window" })
end

-- Screenshots always go to ~/Pictures/Screenshots and the clipboard.
bind("Print", "region fullscreen", "Screenshot of the screen (file + clipboard)")
bind("CTRL + Print", "region screenshot", "Screenshot of a region or window (file + clipboard)")
bind("SUPER + SHIFT + S", "region screenshot", "Screenshot / OCR / record a region")
bind("SUPER + SHIFT + X", "region ocr", "Copy text from a region (OCR)")
bind("SUPER + SHIFT + T", "region translate", "Translate text from a region")
bind("SUPER + SHIFT + R", "region record", "Record a region (again to stop)")

-- Tap Super alone for the launcher too. Watched from raw key events: it's a tap when
-- Super goes down and up within half a second with no other key in between, and
-- nothing moved meanwhile (Super + wheel through workspaces, Super + drag or click
-- on a window are mouse actions, not keys).
local SUPER_KEYS = { [133] = true, [134] = true } -- xkb keycodes of Super_L / Super_R
local superTap = nil
local function snapshot()
    return { ws = tostring(hl.get_active_workspace()), win = tostring(hl.get_active_window()), cursor = hl.get_cursor_pos() }
end
if hl.unbind then
    -- ii's Super binds (its search / workspace numbers) would fire alongside.
    for _, key in ipairs({ "Super_L", "Super_R", "SUPER + Super_L", "SUPER + Super_R" }) do
        hl.unbind(key)
    end
end
hl.on("input.keyboard.key", function(keycode, time, pressed)
    -- Wait Mode (below) shuts the keyboard out: not even a Super tap opens the launcher.
    if hl.get_current_submap and hl.get_current_submap() == "hi-wait" then
        superTap = nil
        return
    end
    if SUPER_KEYS[keycode] then
        if pressed == 1 then
            superTap = snapshot()
            superTap.time = time
        elseif superTap then
            local tap, now = superTap, snapshot()
            superTap = nil
            local moved = math.abs(now.cursor.x - tap.cursor.x) + math.abs(now.cursor.y - tap.cursor.y)
            if time - tap.time < 500 and now.ws == tap.ws and now.win == tap.win and moved < 8 then
                hl.exec_cmd("qs -c hi-shell ipc call launcher toggle")
            end
        end
    elseif pressed == 1 then
        superTap = nil -- another key while Super is held: a shortcut, not a tap
    end
end)

------------------------------------------------------------------------------
-- Window rules
------------------------------------------------------------------------------

-- Focus Mode settings: a regular window (its title ends with "· hi-shell"), floating
-- in the middle like a dialog.
local focusSettings = { class = "^(org.quickshell)$", title = "^(.*) · hi-shell$" }
hl.window_rule({ match = focusSettings, float = true })
hl.window_rule({ match = focusSettings, size = {920, 680} })
hl.window_rule({ match = focusSettings, center = true })

------------------------------------------------------------------------------
-- Layer rules
------------------------------------------------------------------------------

-- Blur behind the translucent panels; ignore_alpha keeps their fully transparent parts unblurred.
for _, name in ipairs({
    "launcher", "ai", "switcher", "display", "overview", "session", "dock", "settings",
    "wallpapers", "sidebar", "calendar", "bar", "notifications", "osd",
}) do
    hl.layer_rule({ match = { namespace = "hi-shell-" .. name }, blur = true })
    hl.layer_rule({ match = { namespace = "hi-shell-" .. name }, ignore_alpha = 0.3 })
end
hl.layer_rule({ match = { namespace = "hi-shell-polkit" }, blur = true })

-- The region selector shows a frozen screenshot; no animation so it doesn't flicker.
hl.layer_rule({ match = { namespace = "hi-shell-region" }, no_anim = true })

------------------------------------------------------------------------------
-- Settings overrides
------------------------------------------------------------------------------

-- Monitor and look & feel overrides made in hi-shell's settings app (generated file).
local overrides = os.getenv("HOME") .. "/.config/hi-shell/hyprland.lua"
local f = io.open(overrides, "r")
if f then
    f:close()
    dofile(overrides)
end

------------------------------------------------------------------------------
-- Wait Mode
------------------------------------------------------------------------------

-- Wait Mode (wait-mode/wait-mode.sh): while it covers the screens, this submap has no binds,
-- so no key bind fires (a bind in the default submap isn't active inside another one).
-- The one bind it has is the way out if the cover itself fails: Ctrl+Alt+Shift+Escape.
hl.define_submap("hi-wait", function()
    hl.bind("CTRL + ALT + SHIFT + Escape",
        hl.dsp.exec_cmd(os.getenv("HOME") .. "/.config/quickshell/hi-shell/wait-mode/wait-mode.sh stop"),
        { description = "Wait Mode: emergency exit" })
end)
