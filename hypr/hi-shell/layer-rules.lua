-- Rules for the shell's panels (layer surfaces).

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
