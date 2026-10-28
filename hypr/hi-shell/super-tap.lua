-- Tap Super alone for the launcher too. Watched from raw key events: it's a tap when
-- Super goes down and up within half a second with no other key in between, and
-- nothing moved meanwhile (Super + wheel through workspaces, Super + drag or click
-- on a window are mouse actions, not keys).
local SUPER_KEYS = { [133] = true, [134] = true } -- xkb keycodes of Super_L / Super_R
local superTap = nil
local function snapshot()
    return { ws = tostring(hl.get_active_workspace()), win = tostring(hl.get_active_window()), cursor = hl.get_cursor_pos() }
end
if hl.unbind then
    -- ii's Super binds (its search / workspace numbers) would fire alongside.
    for _, key in ipairs({ "Super_L", "Super_R", "SUPER + Super_L", "SUPER + Super_R" }) do
        hl.unbind(key)
    end
end
hl.on("input.keyboard.key", function(keycode, time, pressed)
    -- Wait Mode (below) shuts the keyboard out: not even a Super tap opens the launcher.
    if hl.get_current_submap and hl.get_current_submap() == "hi-wait" then
        superTap = nil
        return
    end
    if SUPER_KEYS[keycode] then
        if pressed == 1 then
            superTap = snapshot()
            superTap.time = time
        elseif superTap then
            local tap, now = superTap, snapshot()
            superTap = nil
            local moved = math.abs(now.cursor.x - tap.cursor.x) + math.abs(now.cursor.y - tap.cursor.y)
            if time - tap.time < 500 and now.ws == tap.ws and now.win == tap.win and moved < 8 then
                hl.exec_cmd("qs -c hi-shell ipc call launcher toggle")
            end
        end
    elseif pressed == 1 then
        superTap = nil -- another key while Super is held: a shortcut, not a tap
    end
end)
