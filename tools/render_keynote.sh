#!/usr/bin/env bash
# Renders the keynote (the first-run welcome show, modules/secret/Keynote.qml) to a video:
# frame by frame on the show's own clock, so nothing is dropped however slow the machine is,
# with its track (sounds/secret/keynote.ogg) under it and the finale played twice.
#
#   tools/render_keynote.sh [out.mp4] [width] [height] [fps]
#
# Defaults: ~/Videos/hi-shell-keynote.mp4, 1920x1080, 60 fps. The language is HI_SHELL_LANG
# (en by default, for a video), else the shell's own. Needs quickshell (qs), ffmpeg and bc.
# A window opens while it renders (about as long as the video, or a few times that); leave it be.
set -euo pipefail

here="$(cd "$(dirname "$0")/.." && pwd)"
out="${1:-$HOME/Videos/hi-shell-keynote.mp4}"
width="${2:-1920}"
height="${3:-1080}"
fps="${4:-60}"
# The slides (46 s) and the finale's 16 s loop twice; the last seconds fade out
seconds=78
fade=2.5
chunk=300

work="$(mktemp -d "${TMPDIR:-/tmp}/hi-keynote.XXXXXX")"
trap 'kill "${qs_pid:-}" 2>/dev/null || true; rm -rf "$work"' EXIT
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
        implicitWidth: 960
        implicitHeight: 540
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
                    r.saveToFile("$work/frames/" + String(n).padStart(6, "0") + ".png");
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
    ffmpeg -v error -y -framerate "$fps" -start_number "$1" -i "$work/frames/%06d.png" -frames:v "$2" \
        -c:v libx264 -preset slow -crf 16 -pix_fmt yuv420p -r "$fps" "$work/parts/$(printf %06d "$1").mp4"
    for ((i = $1; i < $1 + $2; i++)); do rm -f "$work/frames/$(printf %06d "$i").png"; done
}

echo "rendering $total frames at ${width}x${height}, $fps fps..."
HI_SHELL_LANG="${HI_SHELL_LANG:-en}" qs -p "$work/config/shell.qml" >"$work/qs.log" 2>&1 &
qs_pid=$!
frame_file() { printf '%s/frames/%06d.png' "$work" "$1"; }
next=0
while (( next < total )); do
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
