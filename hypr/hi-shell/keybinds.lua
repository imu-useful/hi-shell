-- Keybinds. They go through IPC rather than Hyprland global shortcuts: Quickshell (0.3.2)
-- segfaults on exit while destroying GlobalShortcut objects.
--
-- Each bind is a plain hl.bind: the keys, what to run, and a description (the launcher lists
-- it when you type "<", and `hyprctl binds` shows it). The commands are IPC calls to the shell,
-- `qs -c hi-shell ipc call <target> <function>`; change the keys on the left to rebind.

-- Another shell's binds on the same keys (ii's, say) would fire alongside these. This drops them
-- first; delete the block if you have none. Add a key here when you add a bind for it below.
if hl.unbind then
    for _, keys in ipairs({
        "SUPER + Space",
        "SUPER + V",
        "SUPER + Period",
        "SUPER + Y",
        "SUPER + Z",
        "SUPER + U",
        "SUPER + Tab",
        "SUPER + R",
        "SUPER + Escape",
        "CTRL + ALT + Delete",
        "XF86Display",
        "ALT + Tab",
        "ALT + SHIFT + Tab",
        "Print",
        "CTRL + Print",
        "SUPER + SHIFT + S",
        "SUPER + SHIFT + X",
        "SUPER + SHIFT + T",
        "SUPER + SHIFT + R",
    }) do
        hl.unbind(keys)
    end
end

-- Launcher (Super+D is commonly bound to maximize, so Super+Space is the default)
hl.bind("SUPER + Space", hl.dsp.exec_cmd("qs -c hi-shell ipc call launcher toggle"), { description = "hi-shell: Toggle app launcher" })
hl.bind("SUPER + V", hl.dsp.exec_cmd("qs -c hi-shell ipc call launcher search ';'"), { description = "hi-shell: Clipboard history" })
hl.bind("SUPER + Period", hl.dsp.exec_cmd("qs -c hi-shell ipc call launcher search ':'"), { description = "hi-shell: Emoji" })

-- Panels
hl.bind("SUPER + Y", hl.dsp.exec_cmd("qs -c hi-shell ipc call ai toggle"), { description = "hi-shell: Toggle Claude AI palette" }) -- Super+A / Super+C are commonly taken
hl.bind("SUPER + Z", hl.dsp.exec_cmd("qs -c hi-shell ipc call sidebarLeft toggle"), { description = "hi-shell: Toggle left sidebar" })
hl.bind("SUPER + U", hl.dsp.exec_cmd("qs -c hi-shell ipc call sidebarRight toggle"), { description = "hi-shell: Toggle right sidebar" })
hl.bind("SUPER + Tab", hl.dsp.exec_cmd("qs -c hi-shell ipc call overview toggle"), { description = "hi-shell: Workspace overview" })
hl.bind("SUPER + R", hl.dsp.exec_cmd("qs -c hi-shell ipc call wallpaper toggleSelector"), { description = "hi-shell: Wallpaper picker" })
hl.bind("SUPER + Escape", hl.dsp.exec_cmd("qs -c hi-shell ipc call settings toggle"), { description = "hi-shell: Settings" })
hl.bind("CTRL + ALT + Delete", hl.dsp.exec_cmd("qs -c hi-shell ipc call session toggleScreen"), { description = "hi-shell: Session menu" })
-- The laptop's display key (Fn+F10 on Lenovo): display mode picker, again for the next mode.
hl.bind("XF86Display", hl.dsp.exec_cmd("qs -c hi-shell ipc call display next"), { description = "hi-shell: Display mode" })

-- Alt+Tab: hold Alt, Tab / Shift+Tab through recent windows, release Alt to switch.
hl.bind("ALT + Tab", hl.dsp.exec_cmd("qs -c hi-shell ipc call switcher next"), { description = "hi-shell: Switch windows" })
hl.bind("ALT + SHIFT + Tab", hl.dsp.exec_cmd("qs -c hi-shell ipc call switcher prev"), { description = "hi-shell: Switch windows (back)" })
for _, key in ipairs({ "Alt_L", "Alt_R" }) do
    hl.bind(key, hl.dsp.exec_cmd("qs -c hi-shell ipc call switcher commit"),
        { release = true, ignore_mods = true, transparent = true, description = "hi-shell: Switch to the chosen window" })
end

-- Screenshots always go to ~/Pictures/Screenshots and the clipboard.
hl.bind("Print", hl.dsp.exec_cmd("qs -c hi-shell ipc call region fullscreen"), { description = "hi-shell: Screenshot of the screen (file + clipboard)" })
hl.bind("CTRL + Print", hl.dsp.exec_cmd("qs -c hi-shell ipc call region screenshot"), { description = "hi-shell: Screenshot of a region or window (file + clipboard)" })
hl.bind("SUPER + SHIFT + S", hl.dsp.exec_cmd("qs -c hi-shell ipc call region screenshot"), { description = "hi-shell: Screenshot / OCR / record a region" })
hl.bind("SUPER + SHIFT + X", hl.dsp.exec_cmd("qs -c hi-shell ipc call region ocr"), { description = "hi-shell: Copy text from a region (OCR)" })
hl.bind("SUPER + SHIFT + T", hl.dsp.exec_cmd("qs -c hi-shell ipc call region translate"), { description = "hi-shell: Translate text from a region" })
hl.bind("SUPER + SHIFT + R", hl.dsp.exec_cmd("qs -c hi-shell ipc call region record"), { description = "hi-shell: Record a region (again to stop)" })
