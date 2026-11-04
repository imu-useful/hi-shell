import QtQuick
import Quickshell
import Quickshell.Io
import qs.common

// Flappy, for the empty notification center. Click (or Space / Up) flaps; go through the gaps. Drawn on a
// Canvas in the palette's colors; the best score is kept in ~/.local/state/hi-shell/flappy.txt.
// Only ticks while playing.
Item {
    id: root

    readonly property int headerHeight: 24
    readonly property int boardHeight: 190
    readonly property int birdX: 52
    readonly property int birdRadius: 8
    readonly property int pipeWidth: 24
    readonly property int gapSize: 66

    implicitHeight: headerHeight + boardHeight + 4

    // idle | playing | over
    property string phase: "idle"
    property int score: 0
    property int best: 0
    property real birdY: boardHeight / 2
    property real velocity: 0
    // [{ x, gapTop, passed }]
    property var pipes: []
    property real lastTime: 0

    function start() {
        birdY = boardHeight / 2;
        velocity = -4.4;
        pipes = [];
        score = 0;
        lastTime = Date.now();
        phase = "playing";
        forceActiveFocus();
        canvas.requestPaint();
    }

    function flap() {
        if (phase !== "playing")
            return start();
        velocity = -4.4;
    }

    function gameOver() {
        phase = "over";
        if (score > best) {
            best = score;
            bestFile.setText(String(best) + "\n");
        }
        canvas.requestPaint();
    }

    // One step; `k` is the elapsed time in 60ths of a second.
    function step(k) {
        velocity += 0.32 * k;
        birdY += velocity * k;
        const next = [];
        for (const p of pipes) {
            const x = p.x - 2.1 * k;
            if (x > -pipeWidth)
                next.push({ x, gapTop: p.gapTop, passed: p.passed });
        }
        if (next.length === 0 || next[next.length - 1].x < width - 120)
            next.push({ x: width + 10, gapTop: 24 + Math.random() * (boardHeight - gapSize - 48), passed: false });
        for (const p of next) {
            if (!p.passed && p.x + pipeWidth < birdX - birdRadius) {
                p.passed = true;
                score++;
            }
        }
        pipes = next;
        if (birdY < birdRadius || birdY > boardHeight - birdRadius)
            return gameOver();
        for (const p of pipes) {
            const inX = birdX + birdRadius > p.x && birdX - birdRadius < p.x + pipeWidth;
            if (inX && (birdY - birdRadius < p.gapTop || birdY + birdRadius > p.gapTop + gapSize))
                return gameOver();
        }
        canvas.requestPaint();
    }

    Timer {
        interval: 16
        running: root.phase === "playing" && root.visible
        repeat: true
        onTriggered: {
            const now = Date.now();
            const k = Math.min(3, (now - root.lastTime) / 16.667);
            root.lastTime = now;
            root.step(k);
        }
    }

    Canvas {
        id: canvas
        anchors.fill: parent

        readonly property color ink: Colors.m3onSurfaceVariant
        readonly property color accent: Colors.m3primary
        readonly property color pipeColor: Colors.m3tertiary
        readonly property color faint: Colors.m3outlineVariant

        onInkChanged: requestPaint()
        onAccentChanged: requestPaint()

        onPaint: {
            const ctx = getContext("2d");
            ctx.reset();
            const y0 = root.headerHeight;

            ctx.fillStyle = ink;
            ctx.font = `bold 12px "${Appearance.font.mono}"`;
            ctx.textAlign = "right";
            const pad = n => String(n).padStart(3, "0");
            ctx.fillText(`HI ${pad(root.best)}  ${pad(root.score)}`, width - 8, 16);

            ctx.strokeStyle = faint;
            ctx.lineWidth = 1;
            ctx.strokeRect(0.5, y0 - 0.5, width - 1, root.boardHeight + 1);

            ctx.save();
            ctx.beginPath();
            ctx.rect(1, y0, width - 2, root.boardHeight);
            ctx.clip();

            // Pipes
            ctx.fillStyle = pipeColor;
            for (const p of root.pipes) {
                ctx.fillRect(p.x, y0, root.pipeWidth, p.gapTop);
                ctx.fillRect(p.x, y0 + p.gapTop + root.gapSize, root.pipeWidth, root.boardHeight - p.gapTop - root.gapSize);
            }

            // The bird tilts with its speed.
            ctx.translate(root.birdX, y0 + root.birdY);
            ctx.rotate(Math.max(-0.5, Math.min(1.0, root.velocity / 9)));
            ctx.fillStyle = accent;
            ctx.beginPath();
            ctx.arc(0, 0, root.birdRadius, 0, Math.PI * 2);
            ctx.fill();
            ctx.fillStyle = Colors.m3onPrimary;
            ctx.beginPath();
            ctx.arc(3, -2, 2, 0, Math.PI * 2);
            ctx.fill();
            ctx.restore();

            ctx.textAlign = "center";
            ctx.fillStyle = ink;
            if (root.phase === "idle") {
                ctx.font = `13px "${Appearance.font.main}"`;
                ctx.fillText(Translation.tr("Nothing new"), width / 2, y0 + 70);
                ctx.fillStyle = faint;
                ctx.font = `12px "${Appearance.font.main}"`;
                ctx.fillText(Translation.tr("Click to play flappy"), width / 2, y0 + 92);
            } else if (root.phase === "over") {
                ctx.font = `bold 15px "${Appearance.font.mono}"`;
                ctx.fillText("G A M E   O V E R", width / 2, y0 + 78);
                ctx.fillStyle = faint;
                ctx.font = `12px "${Appearance.font.main}"`;
                ctx.fillText(Translation.tr("Click to try again"), width / 2, y0 + 100);
            }
        }
    }

    onWidthChanged: canvas.requestPaint()
    Connections {
        target: Translation
        function onStringsChanged() {
            canvas.requestPaint();
        }
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onPressed: root.flap()
    }

    focus: true
    Keys.onPressed: event => {
        if (event.key === Qt.Key_Space || event.key === Qt.Key_Up || event.key === Qt.Key_W) {
            root.flap();
            event.accepted = true;
        }
    }

    FileView {
        id: bestFile
        path: `${Paths.state}/flappy.txt`
        printErrors: false
        onLoaded: {
            root.best = parseInt(text()) || 0;
            canvas.requestPaint();
        }
    }
}
