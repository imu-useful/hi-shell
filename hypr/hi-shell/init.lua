-- hi-shell Hyprland integration (Lua config, Hyprland 0.56+).
-- install.sh copies this folder to ~/.config/hypr/hi-shell/ and loads it from your config:
--   dofile(os.getenv("HOME") .. "/.config/hypr/hi-shell/init.lua")
-- The files are yours to edit (change a key, add a rule); update.sh doesn't overwrite your
-- changes, it puts the new version next to the file as <name>.lua.new when the two differ.
--
--   startup.lua       start the shell with Hyprland
--   keybinds.lua      keybinds (IPC calls to the shell)
--   super-tap.lua     a tap on Super alone opens the launcher
--   window-rules.lua  rules for hi-shell's windows
--   layer-rules.lua   blur and animation rules for the shell's panels
--   overrides.lua     monitor and look & feel set in hi-shell's settings (generated file)
--   wait-mode.lua     the submap Wait Mode switches to (no binds, so no key fires)

local source = debug and debug.getinfo and debug.getinfo(1, "S").source or ""
local dir = source:match("^@(.*/)") or (os.getenv("HOME") .. "/.config/hypr/hi-shell/")

for _, name in ipairs({ "startup", "keybinds", "super-tap", "window-rules", "layer-rules", "overrides", "wait-mode" }) do
    dofile(dir .. name .. ".lua")
end
