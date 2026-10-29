.pragma library

// Qt key -> the name Hyprland knows (xkb keysyms), shared by every keys field (one table, not
// one per field). `modifiers` are keys that aren't a shortcut by themselves.
const Qt_ = Qt;

const names = {};
function add(key, name) {
    if (key !== undefined)
        names[key] = name;
}
add(Qt_.Key_Space, "Space"); add(Qt_.Key_Return, "Return"); add(Qt_.Key_Enter, "Return"); add(Qt_.Key_Tab, "Tab");
add(Qt_.Key_Backspace, "BackSpace"); add(Qt_.Key_Delete, "Delete"); add(Qt_.Key_Insert, "Insert");
add(Qt_.Key_Home, "Home"); add(Qt_.Key_End, "End"); add(Qt_.Key_PageUp, "Prior"); add(Qt_.Key_PageDown, "Next");
add(Qt_.Key_Left, "left"); add(Qt_.Key_Right, "right"); add(Qt_.Key_Up, "up"); add(Qt_.Key_Down, "down");
add(Qt_.Key_Print, "Print"); add(Qt_.Key_Period, "period"); add(Qt_.Key_Comma, "comma"); add(Qt_.Key_Minus, "minus");
add(Qt_.Key_Equal, "equal"); add(Qt_.Key_Slash, "slash"); add(Qt_.Key_Backslash, "backslash");
add(Qt_.Key_Semicolon, "semicolon"); add(Qt_.Key_Apostrophe, "apostrophe"); add(Qt_.Key_BracketLeft, "bracketleft");
add(Qt_.Key_BracketRight, "bracketright"); add(Qt_.Key_QuoteLeft, "grave");
add(Qt_.Key_VolumeUp, "XF86AudioRaiseVolume"); add(Qt_.Key_VolumeDown, "XF86AudioLowerVolume"); add(Qt_.Key_VolumeMute, "XF86AudioMute");
add(Qt_.Key_MediaPlay, "XF86AudioPlay"); add(Qt_.Key_MediaTogglePlayPause, "XF86AudioPlay"); add(Qt_.Key_MediaNext, "XF86AudioNext");
add(Qt_.Key_MediaPrevious, "XF86AudioPrev"); add(Qt_.Key_MediaStop, "XF86AudioStop");
add(Qt_.Key_MonBrightnessUp, "XF86MonBrightnessUp"); add(Qt_.Key_MonBrightnessDown, "XF86MonBrightnessDown");
add(Qt_.Key_MicMute, "XF86AudioMicMute");

const modifiers = [Qt_.Key_Shift, Qt_.Key_Control, Qt_.Key_Alt, Qt_.Key_Meta, Qt_.Key_AltGr, Qt_.Key_Super_L, Qt_.Key_Super_R, Qt_.Key_CapsLock];

// "SUPER + SHIFT + S" from a key (Qt.Key_*), the modifiers (Qt.*Modifier bits) and the
// key's scan code, or "" when it's only a modifier.
function combo(key, mods, scanCode) {
    if (modifiers.includes(key))
        return "";
    let name = names[key];
    if (name === undefined) {
        if (key >= Qt_.Key_F1 && key <= Qt_.Key_F35)
            name = "F" + (key - Qt_.Key_F1 + 1);
        else if ((key >= Qt_.Key_A && key <= Qt_.Key_Z) || (key >= Qt_.Key_0 && key <= Qt_.Key_9))
            name = String.fromCharCode(key);
        // Anything else (another layout's letters, shifted symbols): the key's code, which
        // Hyprland binds as code:N whatever the layout.
        else if (scanCode > 0)
            name = "code:" + scanCode;
        else
            return "";
    }
    const out = [];
    if (mods & Qt_.MetaModifier)
        out.push("SUPER");
    if (mods & Qt_.ControlModifier)
        out.push("CTRL");
    if (mods & Qt_.AltModifier)
        out.push("ALT");
    if (mods & Qt_.ShiftModifier)
        out.push("SHIFT");
    out.push(name);
    return out.join(" + ");
}
