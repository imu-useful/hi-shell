#!/usr/bin/env bash
# Renders the keynote (the first-run welcome show, modules/secret/Keynote.qml) to a video:
# frame by frame on the show's own clock, so nothing is dropped however slow the machine is,
# with its track (sounds/secret/keynote.ogg) under it and the finale played twice.
#
#   tools/render_keynote.sh [out.mp4] [width] [height] [fps]
#
# Defaults: ~/Videos/hi-shell-keynote.mp4, 1920x1080, 60 fps. The language is HI_SHELL_LANG
# (en by default, for a video). Needs quickshell (qs), ffmpeg, bc and (on Hyprland) python3.
# A small window opens while it renders (around ten minutes) and is pinned to every workspace on
# Hyprland: it has to stay on screen, a hidden window gets no frames and the render stalls.
set -euo pipefail

here="$(cd "$(dirname "$0")/.." && pwd)"
out="${1:-$HOME/Videos/hi-shell-keynote.mp4}"
width="${2:-1920}"
height="${3:-1080}"
fps="${4:-60}"
# The slides (46 s) and the finale's 16 s loop twice; the last seconds fade out
seconds=78
fade=2.5
# Frames are saved uncompressed (PPM: ten times faster than PNG, ~6 MB each) and encoded in chunks;
# the renderer is paused while more than `backlog` frames wait, so they never fill the disk
chunk=120
backlog=600

cache="${XDG_CACHE_HOME:-$HOME/.cache}"
mkdir -p "$cache"
work="$(mktemp -d "$cache/hi-keynote.XXXXXX")"
trap 'kill -CONT "${qs_pid:-}" 2>/dev/null || true; kill "${qs_pid:-}" 2>/dev/null || true; rm -rf "$work"' EXIT
mkdir -p "$work/config" "$work/frames" "$work/parts" "$(dirname "$out")"

# A config next to everything of the shell's (so `qs.*` imports resolve and the show's numbers are
# counted from the real tree), with its own shell.qml
for f in "$here"/*; do [[ "$(basename "$f")" == shell.qml ]] || ln -s "$f" "$work/config/"; done
total=$(( seconds * fps ))
cat > "$work/config/shell.qml" <<EOF
import QtQuick
import Quickshell
import qs.modules.secret

ShellRoot {
    FloatingWindow {
        id: w
        implicitWidth: 320
        implicitHeight: 180
        color: "black"
        title: "hi-shell keynote render"

        property int frame: 0
        property bool busy: false
        property bool armed: false

        Rectangle {
            id: stage
            width: $width
            height: $height
            color: "black"

            Keynote {
                id: show
                anchors.fill: parent
                revealed: true
                external: true
                skippable: false
            }

            // The fade to black at the end
            Rectangle {
                anchors.fill: parent
                color: "black"
                opacity: Math.max(0, Math.min(1, (show.time - ($seconds - $fade)) / $fade))
            }
        }

        // Step the show's clock, let it settle for a tick, grab, save, repeat
        Timer {
            interval: 5
            running: true
            repeat: true
            onTriggered: {
                if (w.busy)
                    return;
                if (w.frame >= $total) {
                    Qt.quit();
                    return;
                }
                if (!w.armed) {
                    show.time = w.frame / $fps;
                    w.armed = true;
                    return;
                }
                w.busy = true;
                const n = w.frame;
                stage.grabToImage(r => {
                    r.saveToFile("$work/frames/" + String(n).padStart(6, "0") + ".ppm");
                    w.frame++;
                    w.armed = false;
                    w.busy = false;
                });
            }
        }
    }
}
EOF

encode() { # first frame, count
    ffmpeg -v error -y -framerate "$fps" -start_number "$1" -i "$work/frames/%06d.ppm" -frames:v "$2" \
        -c:v libx264 -preset medium -crf 16 -pix_fmt yuv420p -r "$fps" "$work/parts/$(printf %06d "$1").mp4"
    for ((i = $1; i < $1 + $2; i++)); do rm -f "$work/frames/$(printf %06d "$i").ppm"; done
}

echo "rendering $total frames at ${width}x${height}, $fps fps..."
HI_SHELL_LANG="${HI_SHELL_LANG:-en}" qs -p "$work/config/shell.qml" >"$work/qs.log" 2>&1 &
qs_pid=$!
frame_file() { printf '%s/frames/%06d.ppm' "$work" "$1"; }

# On Hyprland, float the window and pin it to every workspace (the Lua config's syntax, else the
# classic one), so it keeps getting frames whatever workspace is on screen
pin_window() {
    command -v hyprctl >/dev/null || return 0
    local address
    for _ in $(seq 20); do
        address=$(hyprctl clients -j 2>/dev/null | python3 -c 'import json, sys
print(next((c["address"] for c in json.load(sys.stdin) if c["title"] == "hi-shell keynote render"), ""))' 2>/dev/null || true)
        [[ -n "$address" ]] && break
        sleep 0.5
    done
    [[ -n "$address" ]] || return 0
    if hyprctl dispatch "hl.dsp.window.float({ window = \"address:$address\" })" 2>/dev/null | grep -q ok; then
        hyprctl dispatch "hl.dsp.window.resize({ window = \"address:$address\", x = 320, y = 180 })" >/dev/null 2>&1
        hyprctl dispatch "hl.dsp.window.pin({ window = \"address:$address\" })" >/dev/null 2>&1
    else
        hyprctl dispatch setfloating "address:$address" >/dev/null 2>&1
        hyprctl dispatch resizewindowpixel exact 320 180,"address:$address" >/dev/null 2>&1
        hyprctl dispatch pin "address:$address" >/dev/null 2>&1
    fi
}
pin_window
next=0
while (( next < total )); do
    waiting=$(find "$work/frames" -name '*.ppm' | wc -l)
    if (( waiting > backlog )); then kill -STOP "$qs_pid" 2>/dev/null || true; else kill -CONT "$qs_pid" 2>/dev/null || true; fi
    end=$(( next + chunk < total ? next + chunk : total ))
    # A chunk is done once the frame after it exists (or, for the last one, once qs has quit)
    if [[ -f "$(frame_file $((end - 1)))" ]] && { [[ -f "$(frame_file "$end")" ]] || ! kill -0 "$qs_pid" 2>/dev/null; }; then
        encode "$next" $(( end - next ))
        next=$end
        echo "  $next / $total"
    elif ! kill -0 "$qs_pid" 2>/dev/null; then
        echo "quickshell stopped early:" >&2
        tail -20 "$work/qs.log" >&2
        exit 1
    else
        sleep 0.5
    fi
done

echo "muxing..."
ls "$work/parts"/*.mp4 | sed "s/^/file '/; s/$/'/" > "$work/parts.txt"
ffmpeg -v error -y -f concat -safe 0 -i "$work/parts.txt" -c copy "$work/video.mp4"
# The track as far as the finale's loop end (62 s), then the loop (46-62 s) once more, fading out
track="$here/sounds/secret/keynote.ogg"
ffmpeg -v error -y -i "$track" -i "$track" -filter_complex \
    "[0:a]atrim=0:62,asetpts=PTS-STARTPTS[a];[1:a]atrim=46:62,asetpts=PTS-STARTPTS[b];[a][b]concat=n=2:v=0:a=1,atrim=0:$seconds,afade=t=out:st=$(echo "$seconds - $fade" | bc):d=$fade[out]" \
    -map "[out]" -c:a aac -b:a 256k "$work/audio.m4a"
ffmpeg -v error -y -i "$work/video.mp4" -i "$work/audio.m4a" -c:v copy -c:a copy -shortest -movflags +faststart "$out"
echo "done: $out"
