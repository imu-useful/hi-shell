-- Wait Mode (wait-mode/wait-mode.sh): while it covers the screens, this submap has no binds,
-- so no key bind fires (a bind in the default submap isn't active inside another one).
-- The one bind it has is the way out if the cover itself fails: Ctrl+Alt+Shift+Escape.
hl.define_submap("hi-wait", function()
    hl.bind("CTRL + ALT + SHIFT + Escape",
        hl.dsp.exec_cmd(os.getenv("HOME") .. "/.config/quickshell/hi-shell/wait-mode/wait-mode.sh stop"),
        { description = "Wait Mode: emergency exit" })
end)
