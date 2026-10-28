-- Rules for hi-shell's own windows.

-- Focus Mode settings: a regular window (its title ends with "· hi-shell"), floating
-- in the middle like a dialog.
local focusSettings = { class = "^(org.quickshell)$", title = "^(.*) · hi-shell$" }
hl.window_rule({ match = focusSettings, float = true })
hl.window_rule({ match = focusSettings, size = {920, 680} })
hl.window_rule({ match = focusSettings, center = true })
