#!/bin/sh
# Start hi-shell. Renders with Vulkan when a Vulkan driver is installed: it costs
# noticeably less CPU per frame than OpenGL (visualizers, the dancing frame).
# Set QSG_RHI_BACKEND yourself to choose (e.g. QSG_RHI_BACKEND=opengl ./run.sh).
# Extra arguments go to qs (e.g. -d to detach).
if [ -z "$QSG_RHI_BACKEND" ] && ls /usr/share/vulkan/icd.d/*.json >/dev/null 2>&1; then
    export QSG_RHI_BACKEND=vulkan
fi
exec qs -c hi-shell "$@"
