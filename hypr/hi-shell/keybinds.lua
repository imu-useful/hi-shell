-- Keybinds. They go through IPC rather than Hyprland global shortcuts: Quickshell (0.3.2)
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
