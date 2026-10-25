-- hi-shell Hyprland integration (Lua config, Hyprland 0.56+).
-- Copy to ~/.config/hypr/custom/ and `require` it from hyprland.lua,
-- or paste the lines into your own config.

-- App launcher (Super+D is commonly bound to maximize, so Super+Space is the default)
hl.bind("SUPER + Space", hl.dsp.global("hi-shell:launcherToggle"), { description = "hi-shell: Toggle app launcher" })

-- Blur behind the translucent launcher card
hl.layer_rule({ match = { namespace = "hi-shell-launcher" }, blur = true })
hl.layer_rule({ match = { namespace = "hi-shell-launcher" }, ignore_alpha = 0.3 })

-- Claude AI palette (Super+A / Super+C are commonly taken; Super+Y is free by default)
hl.bind("SUPER + Y", hl.dsp.global("hi-shell:aiToggle"), { description = "hi-shell: Toggle Claude AI palette" })
hl.layer_rule({ match = { namespace = "hi-shell-ai" }, blur = true })
hl.layer_rule({ match = { namespace = "hi-shell-ai" }, ignore_alpha = 0.3 })

-- Control center (also opens from the status button on the right of the bar)
hl.bind("SUPER + U", hl.dsp.global("hi-shell:controlCenterToggle"), { description = "hi-shell: Toggle control center" })
hl.layer_rule({ match = { namespace = "hi-shell-controlcenter" }, blur = true })
hl.layer_rule({ match = { namespace = "hi-shell-controlcenter" }, ignore_alpha = 0.3 })

-- Calendar popup (opens from the bar clock)
hl.layer_rule({ match = { namespace = "hi-shell-calendar" }, blur = true })
hl.layer_rule({ match = { namespace = "hi-shell-calendar" }, ignore_alpha = 0.3 })
