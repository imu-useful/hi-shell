-- hi-shell Hyprland integration (Lua config, Hyprland 0.56+).
-- Load it from your config (e.g. ~/.config/hypr/custom/execs.lua):
--   dofile(os.getenv("HOME") .. "/.config/quickshell/hi-shell/hypr/hi-shell.lua")

-- Keybinds go through IPC rather than Hyprland global shortcuts: Quickshell
-- (0.3.2) segfaults on exit while destroying GlobalShortcut objects.

-- Start the shell with Hyprland
hl.on("hyprland.start", function()
    hl.exec_cmd("qs -c hi-shell")
end)

-- App launcher (Super+D is commonly bound to maximize, so Super+Space is the default)
hl.bind("SUPER + Space", hl.dsp.exec_cmd("qs -c hi-shell ipc call launcher toggle"), { description = "hi-shell: Toggle app launcher" })

-- Blur behind the translucent launcher card
hl.layer_rule({ match = { namespace = "hi-shell-launcher" }, blur = true })
hl.layer_rule({ match = { namespace = "hi-shell-launcher" }, ignore_alpha = 0.3 })

-- Claude AI palette (Super+A / Super+C are commonly taken; Super+Y is free by default)
hl.bind("SUPER + Y", hl.dsp.exec_cmd("qs -c hi-shell ipc call ai toggle"), { description = "hi-shell: Toggle Claude AI palette" })
hl.layer_rule({ match = { namespace = "hi-shell-ai" }, blur = true })
hl.layer_rule({ match = { namespace = "hi-shell-ai" }, ignore_alpha = 0.3 })

-- Left sidebar: home / Claude chat / translator / clipboard
hl.bind("SUPER + Z", hl.dsp.exec_cmd("qs -c hi-shell ipc call sidebarLeft toggle"), { description = "hi-shell: Toggle left sidebar" })

-- Right sidebar (also opens from the system icons on the bar)
hl.bind("SUPER + U", hl.dsp.exec_cmd("qs -c hi-shell ipc call sidebarRight toggle"), { description = "hi-shell: Toggle right sidebar" })
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
