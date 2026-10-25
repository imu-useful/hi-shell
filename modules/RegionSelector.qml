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
// recording. Drag to select, or click a window to take exactly that window;
// Esc cancels. The screen is frozen (grim) first, so the overlay is never in
// the picture. Recording shows a pill with the time; click it to stop.
// IPC: `qs -c hi-shell ipc call region screenshot` (ocr, record, stop, fullscreen).
Scope {
    id: root

    property string mode: "screenshot" // screenshot | ocr | record
    property bool selecting: false
    property string frozen: "" // full screenshot of the focused output
    property var screenInfo: null // { name, x, y, scale }
    property var windows: [] // [{ x, y, w, h, title }] on the visible workspace, in output coordinates

    readonly property bool recording: recorder.running
    property real recordStart: 0
    property string recordFile: ""

    readonly property string tmp: Paths.cache + "/region"

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
        const stamp = new Date().toISOString().slice(0, 19).replace(/[T:]/g, "-");

        if (mode === "screenshot") {
            const file = `${Paths.home}/Pictures/Screenshots/${stamp}.png`;
            run(['mkdir -p "$(dirname "$3")" && magick "$1" -crop "$2" +repage "$3" && wl-copy < "$3" && notify-send -a hi-shell -i "$3" "$4" "$5"', frozen, crop, file, Translation.tr("Screenshot copied"), Translation.tr("Saved to %1").arg(file)]);
        } else if (mode === "ocr") {
            const lang = Config.options.capture.ocrLanguages;
            run(['t=$(magick "$1" -crop "$2" +repage png:- | tesseract stdin - -l "$3" 2>/dev/null); if [ -n "$(printf %s "$t" | tr -d "[:space:]")" ]; then printf %s "$t" | wl-copy; notify-send -a hi-shell -i edit-copy "$4" "$(printf %s "$t" | head -c 200)"; else notify-send -a hi-shell "$5"; fi', frozen, crop, lang, Translation.tr("Text copied"), Translation.tr("No text found")]);
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
            Quickshell.execDetached(["sh", "-c", 'f=~/Pictures/Screenshots/$(date +%F_%H-%M-%S).png; mkdir -p ~/Pictures/Screenshots; grim -o "$(hyprctl monitors -j | python3 -c \'import json,sys; print(next(m["name"] for m in json.load(sys.stdin) if m["focused"]))\')" "$f" && wl-copy < "$f" && notify-send -a hi-shell -i "$f" "$1" "$(printf "$2" "$f")"', "sh", Translation.tr("Screenshot copied"), Translation.tr("Saved to %1").replace("%1", "%s")]);
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

            // Dim everything but the selection.
            Rectangle { x: 0; y: 0; width: parent.width; height: window.sel.y; color: Qt.alpha("black", 0.45) }
            Rectangle { x: 0; y: window.sel.y + window.sel.height; width: parent.width; height: parent.height - y; color: Qt.alpha("black", 0.45) }
            Rectangle { x: 0; y: window.sel.y; width: window.sel.x; height: window.sel.height; color: Qt.alpha("black", 0.45) }
            Rectangle { x: window.sel.x + window.sel.width; y: window.sel.y; width: parent.width - x; height: window.sel.height; color: Qt.alpha("black", 0.45) }

            Rectangle {
                x: window.sel.x - 2
                y: window.sel.y - 2
                width: window.sel.width + 4
                height: window.sel.height + 4
                visible: window.sel.width > 0
                color: "transparent"
                radius: 4
                border.width: 2
                border.color: Colors.m3primary

                Rectangle {
                    anchors.top: parent.bottom
                    anchors.topMargin: 6
                    anchors.left: parent.left
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
                onReleased: {
                    const r = window.sel;
                    window.dragging = false;
                    root.finish(r.x, r.y, r.width, r.height);
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
                    model: [{ text: Translation.tr("Screenshot"), icon: "screenshot_region" }, { text: Translation.tr("Text (OCR)"), icon: "document_scanner" }, { text: Translation.tr("Record"), icon: "videocam" }]
                    currentIndex: ["screenshot", "ocr", "record"].indexOf(root.mode)
                    onSelected: index => root.mode = ["screenshot", "ocr", "record"][index]
                }
            }

            StyledText {
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.bottom: parent.bottom
                anchors.bottomMargin: 32
                text: Translation.tr("Drag to select · click a window · Esc or right click to cancel")
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
