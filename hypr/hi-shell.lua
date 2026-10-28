-- Kept so a Hyprland config that still loads
--   ~/.config/quickshell/hi-shell/hypr/hi-shell.lua
-- keeps working. hi-shell's Hyprland files are in the hypr/hi-shell/ folder now: install.sh copies
-- it to ~/.config/hypr/hi-shell/ (where you edit it) and points your config at init.lua there.
-- Until then this loads the folder's copy in the repo, or yours once it exists.
local home = os.getenv("HOME")
local mine = home .. "/.config/hypr/hi-shell/init.lua"
local f = io.open(mine, "r")
if f then
    f:close()
    dofile(mine)
else
    dofile(home .. "/.config/quickshell/hi-shell/hypr/hi-shell/init.lua")
end
