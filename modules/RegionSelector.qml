import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import Quickshell.Wayland
import qs.common
import qs.common.widgets
import qs.services

// Region capture: screenshot (copy + save), OCR (copy the text) or screen
// recording. Drag to select, click a window to take exactly that window, or
// click the empty desktop for the whole screen; Esc cancels. The screen is frozen (grim) first, so the overlay is never in
// the picture. Recording shows a pill with the time; click it to stop.
// IPC: `qs -c hi-shell ipc call region screenshot` (ocr, translate, record, stop, fullscreen).
Scope {
    id: root

    property string mode: "screenshot" // screenshot | ocr | translate | record
    property bool selecting: false
    property string frozen: "" // full screenshot of the focused output
    property var screenInfo: null // { name, x, y, scale }
    property var windows: [] // [{ x, y, w, h, title }] on the visible workspace, in output coordinates

    readonly property bool recording: recorder.running
    property real recordStart: 0
    property string recordFile: ""

    readonly property string tmp: Paths.cache + "/region"

    // Shell snippet: OCR of region $2 of image $1 in languages $3 into $t.
    // tesseract misses light text on dark backgrounds (dark themes, terminals), so
    // the crop is made gray, inverted when it's mostly dark, and enlarged first.
    // "auto" = every installed language.
    readonly property string ocrScript: 'img=$(mktemp --suffix=.png); magick "$1" -crop "$2" +repage -colorspace Gray "$img"; '
        + 'neg=; [ "$(magick "$img" -format "%[fx:mean<0.5]" info:)" = 1 ] && neg=-negate; '
        + 'l="$3"; [ "$l" = auto ] && l=$(tesseract --list-langs 2>/dev/null | tail -n +2 | grep -vx osd | paste -sd+); '
        + 't=$(magick "$img" $neg -resize 200% png:- | tesseract stdin - -l "${l:-eng}" 2>/dev/null); rm -f "$img"; '

    function start(newMode) {
        if (selecting || freeze.running)
            return;
        if (recording) {
            stopRecording();
            return;
        }
        mode = newMode;
        // Close panels that would otherwise be in the picture.
        ShellState.sidebarLeftOpen = ShellState.sidebarRightOpen = ShellState.launcherOpen = false;
        freeze.running = true;
    }

    function finish(x, y, w, h) {
        selecting = false;
        if (w < 4 || h < 4)
            return;
        const s = screenInfo.scale;
        // Pixels in the frozen image are physical: scale the logical selection.
        const crop = `${Math.round(w * s)}x${Math.round(h * s)}+${Math.round(x * s)}+${Math.round(y * s)}`;
        // Local time, same naming as fullscreen shots (`date +%F_%H-%M-%S`).
        const stamp = Qt.formatDateTime(new Date(), "yyyy-MM-dd_HH-mm-ss");

        if (mode === "screenshot") {
            const file = `${Paths.home}/Pictures/Screenshots/${stamp}.png`;
            run(['mkdir -p "$(dirname "$3")" && magick "$1" -crop "$2" +repage "$3" && wl-copy --type image/png < "$3" && notify-send -a hi-shell -i "$3" "$4" "$5"', frozen, crop, file, Translation.tr("Screenshot copied"), Translation.tr("Saved to %1").arg(file)]);
        } else if (mode === "ocr") {
            const lang = Config.options.capture.ocrLanguages;
            run([ocrScript + 'if [ -n "$(printf %s "$t" | tr -d "[:space:]")" ]; then printf %s "$t" | wl-copy; notify-send -a hi-shell -i edit-copy "$4" "$(printf %s "$t" | head -c 200)"; else notify-send -a hi-shell "$5"; fi', frozen, crop, lang, Translation.tr("Text copied"), Translation.tr("No text found")]);
        } else if (mode === "translate") {
            // OCR, then into the translator in the left sidebar.
            translator.command = ["sh", "-c", ocrScript + 'printf %s "$t"', "sh",
                frozen, crop, Config.options.capture.ocrLanguages];
            translator.running = true;
        } else {
            // wf-recorder takes global logical coordinates.
            recordFile = `${Paths.home}/Videos/Recordings/${stamp}.mp4`;
            recorder.command = ["sh", "-c", 'mkdir -p "$(dirname "$2")" && exec wf-recorder -g "$1" -f "$2"' + (Config.options.capture.recordAudio ? " -a" : ""), "sh",
                `${screenInfo.x + Math.round(x)},${screenInfo.y + Math.round(y)} ${Math.round(w)}x${Math.round(h)}`, recordFile];
            recorder.running = true;
            recordStart = Date.now();
        }
    }

    function stopRecording() {
        if (recording)
            Quickshell.execDetached(["pkill", "-INT", "-x", "wf-recorder"]);
    }

    function run(args) {
        const proc = procComponent.createObject(root, { command: ["sh", "-c", args[0], "sh", ...args.slice(1)] });
        proc.exited.connect(() => proc.destroy());
        proc.running = true;
    }

    // Requests from other modules (bar button, quick toggle).
    Connections {
        target: ShellState
        function onCaptureRequestChanged() {
            if (ShellState.captureRequest === "")
                return;
            const mode = ShellState.captureRequest;
            ShellState.captureRequest = "";
            root.start(mode);
        }
    }

    Component {
        id: procComponent
        Process {}
    }

    Process {
        id: translator
        stdout: StdioCollector {
            onStreamFinished: {
                const t = text.replace(/\s+/g, " ").trim();
                if (!t) {
                    Quickshell.execDetached(["notify-send", "-a", "hi-shell", Translation.tr("No text found")]);
                    return;
                }
                ShellState.translatorInput = t;
                ShellState.sidebarLeftTab = "translator";
                ShellState.sidebarLeftOpen = true;
            }
        }
    }

    // Freeze the focused output and collect window rectangles, then show the overlay.
    Process {
        id: freeze
        command: ["sh", "-c", `
            mkdir -p "$1"
            mon=$(hyprctl monitors -j)
            name=$(printf %s "$mon" | python3 -c 'import json,sys; print(next(m["name"] for m in json.load(sys.stdin) if m["focused"]))')
            grim -o "$name" "$1/frozen.png" || exit 1
            printf %s "$mon" | python3 -c '
import json, subprocess, sys
mons = json.load(sys.stdin)
m = next(m for m in mons if m["focused"])
ws = {m["activeWorkspace"]["id"], m["specialWorkspace"]["id"]}
clients = json.loads(subprocess.run(["hyprctl", "clients", "-j"], capture_output=True, text=True).stdout)
wins = [{"x": c["at"][0] - m["x"], "y": c["at"][1] - m["y"], "w": c["size"][0], "h": c["size"][1], "title": c["title"]}
        for c in clients if c["mapped"] and not c["hidden"] and c["workspace"]["id"] in ws]
print(json.dumps({"name": m["name"], "x": m["x"], "y": m["y"], "scale": m["scale"], "windows": wins}))'
        `, "sh", root.tmp]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const info = JSON.parse(text);
                    root.screenInfo = info;
                    root.windows = info.windows;
                    root.frozen = `${root.tmp}/frozen.png`;
                    root.selecting = true;
                } catch (e) {
                    console.warn("Region: could not capture the screen", e);
                    Quickshell.execDetached(["notify-send", "-a", "hi-shell", "-i", "dialog-error", Translation.tr("Couldn't capture the screen"), Translation.tr("The focused screen isn't available to screenshot tools; try again in a moment")]);
                }
            }
        }
    }

    Process {
        id: recorder
        onExited: {
            if (root.recordFile)
                Quickshell.execDetached(["notify-send", "-a", "hi-shell", "-i", "video-x-generic", Translation.tr("Recording saved"), root.recordFile]);
        }
    }

    IpcHandler {
        target: "region"

        function screenshot(): void {
            root.start("screenshot");
        }
        function ocr(): void {
            root.start("ocr");
        }
        // OCR a region and open the text in the translator.
        function translate(): void {
            root.start("translate");
        }
        // Starts a region recording, or stops the one running.
        function record(): void {
            if (root.recording)
                root.stopRecording();
            else
                root.start("record");
        }
        function stop(): void {
            root.stopRecording();
        }
        function cancel(): void {
            root.selecting = false;
        }
        // Whole focused screen straight to clipboard + file, no selection.
        function fullscreen(): void {
            Quickshell.execDetached(["sh", "-c", 'f=~/Pictures/Screenshots/$(date +%F_%H-%M-%S).png; mkdir -p ~/Pictures/Screenshots; grim -o "$(hyprctl monitors -j | python3 -c \'import json,sys; print(next(m["name"] for m in json.load(sys.stdin) if m["focused"]))\')" "$f" && wl-copy --type image/png < "$f" && notify-send -a hi-shell -i "$f" "$1" "$(printf "$2" "$f")"', "sh", Translation.tr("Screenshot copied"), Translation.tr("Saved to %1").replace("%1", "%s")]);
        }
    }

    // --- Selection overlay ---
    LazyLoader {
        active: root.selecting

        PanelWindow {
            id: window

            screen: Quickshell.screens.find(s => s.name === root.screenInfo?.name) ?? Quickshell.screens[0]
            anchors.top: true
            anchors.bottom: true
            anchors.left: true
            anchors.right: true
            exclusionMode: ExclusionMode.Ignore
            color: "black"

            WlrLayershell.namespace: "hi-shell-region"
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

            // Selection in logical px; while not dragging, the hovered window.
            property real sx: 0
            property real sy: 0
            property real ex: 0
            property real ey: 0
            property bool dragging: false
            readonly property var hoveredWindow: dragging ? null : root.windows.find(w => mouse.mouseX >= w.x && mouse.mouseX < w.x + w.w && mouse.mouseY >= w.y && mouse.mouseY < w.y + w.h) ?? null
            readonly property rect sel: dragging ? Qt.rect(Math.min(sx, ex), Math.min(sy, ey), Math.abs(ex - sx), Math.abs(ey - sy))
                                      : hoveredWindow ? Qt.rect(hoveredWindow.x, hoveredWindow.y, hoveredWindow.w, hoveredWindow.h) : Qt.rect(0, 0, 0, 0)

            Image {
                anchors.fill: parent
                source: root.frozen ? `file://${root.frozen}?${Date.now()}` : ""
                cache: false
                fillMode: Image.Stretch
            }

            // The selection as it's drawn: it springs after `sel` (the real one), so a drag is
            // followed with a little lag and overshoot, and hovering windows glides from one to
            // the next. Without a selection it's a point under the cursor, the next one grows from.
            readonly property bool hasSel: sel.width > 0
            property real ax: hasSel ? sel.x : mouse.mouseX
            property real ay: hasSel ? sel.y : mouse.mouseY
            property real aw: hasSel ? sel.width : 0
            property real ah: hasSel ? sel.height : 0
            readonly property bool springy: Appearance.anim.speed > 0 && !Toggles.gameMode && !PowerSaver.enabled
            Behavior on ax { enabled: window.springy; SpringAnimation { spring: 4.5; damping: 0.42; epsilon: 0.25 } }
            Behavior on ay { enabled: window.springy; SpringAnimation { spring: 4.5; damping: 0.42; epsilon: 0.25 } }
            Behavior on aw { enabled: window.springy; SpringAnimation { spring: 4.5; damping: 0.42; epsilon: 0.25 } }
            Behavior on ah { enabled: window.springy; SpringAnimation { spring: 4.5; damping: 0.42; epsilon: 0.25 } }

            // Dim everything but the selection, with the outline around it (shaders/dimming.frag).
            property real dim: window.springy ? 0 : 0.5
            NumberAnimation on dim {
                running: window.springy
                to: 0.5
                duration: Appearance.anim.normal
                easing.type: Easing.OutCubic
            }

            ShaderEffect {
                anchors.fill: parent
                property vector4d selectionRect: Qt.vector4d(window.ax, window.ay, Math.max(0, window.aw), Math.max(0, window.ah))
                property color outlineColor: Colors.m3primary
                property vector2d screenSize: Qt.vector2d(width, height)
                property real dimOpacity: window.dim
                property real borderRadius: 12
                property real outlineThickness: 2
                fragmentShader: Qt.resolvedUrl("../common/widgets/shaders/dimming.frag.qsb")
            }

            // Size of the selection, under its bottom left corner.
            Rectangle {
                x: window.ax
                y: window.ay + Math.max(0, window.ah) + 8
                visible: window.sel.width > 0
                implicitWidth: size.implicitWidth + 16
                implicitHeight: 24
                radius: 12
                color: Colors.m3primary
                StyledText {
                    id: size
                    anchors.centerIn: parent
                    text: `${Math.round(window.sel.width)} × ${Math.round(window.sel.height)}`
                    font.pixelSize: Appearance.font.size.labelSmall
                    color: Colors.m3onPrimary
                }
            }

            MouseArea {
                id: mouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.CrossCursor
                acceptedButtons: Qt.LeftButton | Qt.RightButton
                onPressed: event => {
                    if (event.button === Qt.RightButton) {
                        root.selecting = false;
                        return;
                    }
                    window.sx = window.ex = event.x;
                    window.sy = window.ey = event.y;
                }
                onPositionChanged: event => {
                    if (!pressed)
                        return;
                    window.ex = event.x;
                    window.ey = event.y;
                    if (Math.abs(window.ex - window.sx) > 4 || Math.abs(window.ey - window.sy) > 4)
                        window.dragging = true;
                }
                onReleased: event => {
                    if (event.button !== Qt.LeftButton || !root.selecting)
                        return;
                    // Copy the numbers first: `sel` is a value-type reference, and resetting
                    // `dragging` below would turn it into the hovered window.
                    const r = window.sel;
                    const x = r.x, y = r.y, w = r.width, h = r.height;
                    window.dragging = false;
                    if (w >= 4 && h >= 4)
                        root.finish(x, y, w, h);
                    else
                        // A click on the empty desktop (no window under it): the whole screen.
                        root.finish(0, 0, window.width, window.height);
                }
            }

            // Mode switcher
            Rectangle {
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.top: parent.top
                anchors.topMargin: 24
                implicitWidth: modes.implicitWidth + 16
                implicitHeight: modes.implicitHeight + 16
                radius: height / 2
                color: Colors.m3surfaceContainerHigh

                SegmentedButton {
                    id: modes
                    anchors.centerIn: parent
                    model: [{ text: Translation.tr("Screenshot"), icon: "screenshot_region" }, { text: Translation.tr("Text (OCR)"), icon: "document_scanner" }, { text: Translation.tr("Translate"), icon: "translate" }, { text: Translation.tr("Record"), icon: "videocam" }]
                    currentIndex: ["screenshot", "ocr", "translate", "record"].indexOf(root.mode)
                    onSelected: index => root.mode = ["screenshot", "ocr", "translate", "record"][index]
                }
            }

            StyledText {
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.bottom: parent.bottom
                anchors.bottomMargin: 32
                text: Translation.tr("Drag to select · click a window, or the desktop for the whole screen · Esc or right click to cancel")
                color: "white"
                style: Text.Outline
                styleColor: Qt.alpha("black", 0.6)
            }

            Shortcut {
                sequence: "Escape"
                onActivated: root.selecting = false
            }
        }
    }

    // --- Recording indicator ---
    LazyLoader {
        active: root.recording

        PanelWindow {
            id: recWindow
            screen: Quickshell.screens.find(s => s.name === root.screenInfo?.name) ?? Quickshell.screens[0]
            anchors.top: true
            margins.top: Appearance.sizes.barHeight + Appearance.sizes.barMargin + 10
            exclusiveZone: 0
            implicitWidth: pill.implicitWidth
            implicitHeight: pill.implicitHeight
            color: "transparent"

            WlrLayershell.namespace: "hi-shell-recording"
            WlrLayershell.layer: WlrLayer.Overlay

            property real elapsed: 0
            Timer {
                interval: 500
                running: true
                repeat: true
                triggeredOnStart: true
                onTriggered: recWindow.elapsed = (Date.now() - root.recordStart) / 1000
            }

            Rectangle {
                id: pill
                implicitWidth: row.implicitWidth + 28
                implicitHeight: 40
                radius: 20
                color: Colors.m3errorContainer

                RowLayout {
                    id: row
                    anchors.centerIn: parent
                    spacing: 10
                    Rectangle {
                        implicitWidth: 12
                        implicitHeight: 12
                        radius: 6
                        color: Colors.m3error
                        SequentialAnimation on opacity {
                            loops: Animation.Infinite
                            NumberAnimation { to: 0.3; duration: 700 }
                            NumberAnimation { to: 1; duration: 700 }
                        }
                    }
                    StyledText {
                        text: `REC ${Timers.format(recWindow.elapsed)}`
                        font.weight: Font.DemiBold
                        font.features: { "tnum": 1 }
                        color: Colors.m3onErrorContainer
                    }
                    MaterialIcon {
                        icon: "stop_circle"
                        fill: 1
                        color: Colors.m3onErrorContainer
                    }
                }
                StateLayer {
                    tint: Colors.m3onErrorContainer
                    onClicked: root.stopRecording()
                }
            }
        }
    }
}
