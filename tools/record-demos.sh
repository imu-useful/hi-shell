#!/usr/bin/env bash
# Records the short demo clips for the README (docs/demos/*.webp) from the running shell.
#
# It drives the shell over IPC on an EMPTY workspace (so no windows of yours get into the frame),
# turns Do Not Disturb on for the time (no notification popups), and puts everything back after.
# Panels that show personal data (the notification list, clipboard history, AI chats) are not recorded.
#
#   tools/record-demos.sh            all clips
#   tools/record-demos.sh launcher   one clip
set -u

OUT="$(cd "$(dirname "$0")/.." && pwd)/docs/demos"
TMP="$(mktemp -d)"
QS=(qs -c hi-shell ipc call)
WIDTH=${WIDTH:-960}
FPS=${FPS:-15}
mkdir -p "$OUT"

for tool in wf-recorder ffmpeg wtype hyprctl qs; do
    command -v "$tool" >/dev/null || { echo "missing: $tool" >&2; exit 1; }
done

ws_info() { hyprctl activeworkspace -j | python3 -c "import json,sys;d=json.load(sys.stdin);print(d['id'],d['windows'])"; }
focus_ws() { hyprctl dispatch "hl.dsp.focus({ workspace = $1 })" >/dev/null; sleep 1.2; }
monitor() { hyprctl monitors -j | python3 -c "import json,sys;print(json.load(sys.stdin)[0]['name'])"; }

WAIT_MODE="$(cd "$(dirname "$0")/.." && pwd)/wait-mode/wait-mode.sh"
ORIG_WS=${BACK_TO:-$(ws_info | cut -d" " -f1)}
DND_WAS=$(python3 -c "import json;print(json.load(open('$HOME/.local/state/hi-shell/notifications.json')).get('dnd',False))" 2>/dev/null || echo False)
OUTPUT=$(monitor)

cleanup() {
    pkill -INT wf-recorder 2>/dev/null
    "${QS[@]}" launcher close >/dev/null 2>&1
    "${QS[@]}" settings close >/dev/null 2>&1
    "${QS[@]}" sidebarRight close >/dev/null 2>&1
    "${QS[@]}" calendar close >/dev/null 2>&1
    "${QS[@]}" overview close >/dev/null 2>&1
    "${QS[@]}" welcome close >/dev/null 2>&1
    "$WAIT_MODE" stop >/dev/null 2>&1
    [ "$DND_WAS" = False ] && "${QS[@]}" notifications toggleDnd >/dev/null 2>&1
    focus_ws "$ORIG_WS"
    rm -rf "$TMP"
}
trap cleanup EXIT

# an empty workspace to record on
TARGET=""
for id in $(ws_info | cut -d" " -f1) 4 5 6 7 8 9 10; do
    focus_ws "$id"
    read -r cur windows <<<"$(ws_info)"
    if [ "$cur" = "$id" ] && [ "$windows" = 0 ]; then TARGET=$id; break; fi
done
[ -n "$TARGET" ] || { echo "no empty workspace found" >&2; exit 1; }
echo "recording on workspace $TARGET (back to $ORIG_WS after)"

[ "$DND_WAS" = False ] && "${QS[@]}" notifications toggleDnd >/dev/null
sleep 0.5

key() { for k in "$@"; do wtype -k "$k"; sleep 0.45; done; }

# record NAME SECONDS-OF-ACTION; the action is the function clip_NAME
record() {
    local name=$1 raw="$TMP/$1.mkv"
    echo "== $name"
    wf-recorder -o "$OUTPUT" -f "$raw" -y >/dev/null 2>&1 &
    local pid=$!
    sleep 1.0
    "clip_$name"
    sleep 0.6
    kill -INT $pid 2>/dev/null; wait $pid 2>/dev/null
    ffmpeg -v error -y -ss 0.5 -i "$raw" \
        -vf "fps=$FPS,scale=$WIDTH:-1:flags=lanczos" \
        -c:v libwebp_anim -lossless 0 -q:v 68 -compression_level 4 -loop 0 "$OUT/$name.webp"
    ls -la "$OUT/$name.webp" | awk '{print "   " $5 " bytes"}'
}

clip_launcher() {
    "${QS[@]}" launcher open; sleep 1.4
    wtype "fire"; sleep 1.4
    key Down Down; sleep 0.5
    "${QS[@]}" launcher close; sleep 0.8
}
clip_sidebar() {
    "${QS[@]}" sidebarRight openTab calendar; sleep 1.8
    "${QS[@]}" sidebarRight openTab todo; sleep 1.5
    "${QS[@]}" sidebarRight openTab timers; sleep 1.5
    "${QS[@]}" sidebarRight close; sleep 0.8
}
clip_settings() {
    for page in quick general bar desktop interface sounds; do
        "${QS[@]}" settings open "$page"; sleep 1.5
    done
    "${QS[@]}" settings close; sleep 0.8
}
clip_wallpapers() {
    "${QS[@]}" wallpaper toggleSelector; sleep 1.8
    key Right Right Right Left; sleep 0.5
    "${QS[@]}" wallpaper toggleSelector; sleep 0.8
}
clip_display() {
    "${QS[@]}" display toggle; sleep 1.6
    key Right Right; sleep 0.4
    "${QS[@]}" display toggle; sleep 0.8
}
clip_session() {
    "${QS[@]}" session toggleScreen; sleep 2.2
    "${QS[@]}" session toggleScreen; sleep 0.8
}
clip_desktop_edit() {
    sleep 0.5
    "${QS[@]}" desktop toggleEdit; sleep 3
    "${QS[@]}" desktop toggleEdit; sleep 0.8
}
clip_overview() {
    "${QS[@]}" overview open; sleep 2.2
    "${QS[@]}" overview close; sleep 0.8
}
clip_calendar() {
    "${QS[@]}" calendar open; sleep 2.2
    "${QS[@]}" calendar close; sleep 0.8
}

# Wait Mode locks the keyboard and the mouse while it is on; the trap above always stops it
# (and the way out for a person is Esc three times).
clip_wait_mode() {
    "$WAIT_MODE" start; sleep 6
    "$WAIT_MODE" stop; sleep 1
}

ALL=(launcher sidebar settings wallpapers display session desktop_edit overview calendar wait_mode)
for name in "${@:-${ALL[@]}}"; do record "$name"; done
