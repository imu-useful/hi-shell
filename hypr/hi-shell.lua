-- hi-shell Hyprland integration (Lua config, Hyprland 0.56+).
-- Copy to ~/.config/hypr/custom/ and `require` it from hyprland.lua,
-- or paste the lines into your own config.

-- App launcher (Super+D is commonly bound to maximize, so Super+Space is the default)
hl.bind("SUPER + Space", hl.dsp.global("hi-shell:launcherToggle"), { description = "hi-shell: Toggle app launcher" })

-- Blur behind the translucent launcher card
hl.layer_rule({ match = { namespace = "hi-shell-launcher" }, blur = true })
hl.layer_rule({ match = { namespace = "hi-shell-launcher" }, ignore_alpha = 0.3 })
