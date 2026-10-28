-- Start the shell with Hyprland.
hl.on("hyprland.start", function()
    hl.exec_cmd(os.getenv("HOME") .. "/.config/quickshell/hi-shell/run.sh")
end)
