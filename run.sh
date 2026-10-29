#!/bin/sh
# Start hi-shell. Renders with Vulkan when a Vulkan driver is installed: it costs
# noticeably less CPU per frame than OpenGL (visualizers, the dancing frame).
# Set QSG_RHI_BACKEND yourself to choose (e.g. QSG_RHI_BACKEND=opengl ./run.sh).
# Extra arguments go to qs (e.g. -d to detach).

# Not on the GPUs whose Vulkan driver is partial or software: old Intel (Ivy Bridge, Haswell,
# Broadwell and the like: HD Graphics 2000 to 5xxx) and llvmpipe. Qt draws black windows on
# them (a black desktop and no bar), while OpenGL works.
use_vulkan() {
    ls /usr/share/vulkan/icd.d/*.json >/dev/null 2>&1 || return 1
    gpu=$( { vulkaninfo --summary 2>/dev/null | grep -i deviceName; lspci 2>/dev/null | grep -iE 'vga|3d|display'; } )
    if printf '%s\n' "$gpu" | grep -qiE '\((IVB|BYT|HSW|BDW|CHV)[^)]*\)|HD Graphics [2-5][0-9]{3}([^0-9]|$)|llvmpipe|lavapipe|swrast'; then
        return 1
    fi
    return 0
}

if [ -z "$QSG_RHI_BACKEND" ] && use_vulkan; then
    export QSG_RHI_BACKEND=vulkan
fi

# The icon font (the few hundred icons the shell uses, cut out of Material Symbols) is made
# before the shell starts: a font that changes while it runs shows other icons. Quick when
# nothing changed (a check of the icon names against the last build).
dir=$(cd "$(dirname "$(readlink -f "$0")")" && pwd)
family=$(python3 -c 'import json,os,sys; print(json.load(open(sys.argv[1])).get("appearance", {}).get("fonts", {}).get("icon", "Material Symbols Rounded"))' "${XDG_CONFIG_HOME:-$HOME/.config}/hi-shell/config.json" 2>/dev/null || echo "Material Symbols Rounded")
python3 "$dir/services/icon_font.py" --family "${family:-Material Symbols Rounded}" --scan "$dir" --out "${XDG_CACHE_HOME:-$HOME/.cache}/hi-shell/icons" >/dev/null 2>&1 || true

exec qs -c hi-shell "$@"
