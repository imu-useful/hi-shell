-- Monitor and look & feel overrides made in hi-shell's settings app (generated file).
local overrides = os.getenv("HOME") .. "/.config/hi-shell/hyprland.lua"
local f = io.open(overrides, "r")
if f then
    f:close()
    dofile(overrides)
end
