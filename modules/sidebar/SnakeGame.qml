import QtQuick
import Quickshell
import Quickshell.Io
import qs.common

// Snake, for the empty notification center. Click to start; arrows / WASD turn (or click
// beside the head to turn towards the click). The walls and the snake itself are deadly.
// Drawn on a Canvas in the palette's colors; the best score is kept in
// ~/.local/state/hi-shell/snake.txt. Only ticks while playing.
Item {
    id: root

    readonly property int cell: 14
    readonly property int cols: Math.max(10, Math.floor(width / cell))
    readonly property int rows: 14
    readonly property int headerHeight: 24

    implicitHeight: headerHeight + rows * cell + 4

    // idle | playing | over
    property string phase: "idle"
    property int score: 0
    property int best: 0

    // Head first; directions: 0 up, 1 right, 2 down, 3 left.
    property var snake: []
    property point food: Qt.point(0, 0)
    property int dir: 1
    // Turns asked for between two steps (a quick U-turn through a side step still counts).
    property var turns: []

    readonly property var delta: [[0, -1], [1, 0], [0, 1], [-1, 0]]

    function start() {
        const y = Math.floor(rows / 2), x = Math.floor(cols / 3);
        snake = [{ x, y }, { x: x - 1, y }, { x: x - 2, y }];
        dir = 1;
        turns = [];
        score = 0;
        placeFood();
        phase = "playing";
        forceActiveFocus();
        canvas.requestPaint();
    }

    function placeFood() {
        const taken = new Set(snake.map(p => p.y * cols + p.x));
        const free = [];
        for (let i = 0; i < cols * rows; i++) {
            if (!taken.has(i))
                free.push(i);
        }
        if (free.length === 0)
            return gameOver();
        const i = free[Math.floor(Math.random() * free.length)];
        food = Qt.point(i % cols, Math.floor(i / cols));
    }

    // A turn is ignored if it reverses the snake (against the last turn already asked for).
    function turn(d) {
        if (phase !== "playing")
            return;
        const last = turns.length > 0 ? turns[turns.length - 1] : dir;
        if (d === last || (d + 2) % 4 === last || turns.length >= 2)
            return;
        turns = [...turns, d];
    }

    function step() {
        if (turns.length > 0) {
            dir = turns[0];
            turns = turns.slice(1);
        }
        const head = snake[0];
        const nx = head.x + delta[dir][0], ny = head.y + delta[dir][1];
        const eats = nx === food.x && ny === food.y;
        // The tail moves away this step, unless something was eaten.
        const body = eats ? snake : snake.slice(0, -1);
        if (nx < 0 || ny < 0 || nx >= cols || ny >= rows || body.some(p => p.x === nx && p.y === ny))
            return gameOver();
        snake = [{ x: nx, y: ny }, ...body];
        if (eats) {
            score++;
            placeFood();
        }
        canvas.requestPaint();
    }

    function gameOver() {
        phase = "over";
        if (score > best) {
            best = score;
            bestFile.setText(String(best) + "\n");
        }
        canvas.requestPaint();
    }

    Timer {
        // Faster with every few apples.
        interval: Math.max(60, 130 - root.score * 2)
        running: root.phase === "playing" && root.visible
        repeat: true
        onTriggered: root.step()
    }

    Canvas {
        id: canvas
        anchors.fill: parent

        readonly property color ink: Colors.m3onSurfaceVariant
        readonly property color accent: Colors.m3primary
        readonly property color fruit: Colors.m3tertiary
        readonly property color faint: Colors.m3outlineVariant

        onInkChanged: requestPaint()
        onAccentChanged: requestPaint()

        onPaint: {
            const ctx = getContext("2d");
            ctx.reset();
            const c = root.cell, x0 = (width - root.cols * c) / 2, y0 = root.headerHeight;

            // Header
            ctx.fillStyle = ink;
            ctx.font = `bold 12px "${Appearance.font.mono}"`;
            ctx.textAlign = "right";
            const pad = n => String(n).padStart(3, "0");
            ctx.fillText(`HI ${pad(root.best)}  ${pad(root.score)}`, width - 8, 16);

            // Board
            ctx.strokeStyle = faint;
            ctx.lineWidth = 1;
            ctx.strokeRect(x0 - 0.5, y0 - 0.5, root.cols * c + 1, root.rows * c + 1);

            // Food
            ctx.fillStyle = fruit;
            ctx.beginPath();
            ctx.arc(x0 + (root.food.x + 0.5) * c, y0 + (root.food.y + 0.5) * c, c * 0.34, 0, Math.PI * 2);
            ctx.fill();

            // Snake: the head solid, the body fading a little towards the tail.
            const n = root.snake.length;
            for (let i = n - 1; i >= 0; i--) {
                const p = root.snake[i];
                ctx.globalAlpha = i === 0 ? 1 : Math.max(0.45, 1 - i / (n + 6));
                ctx.fillStyle = accent;
                const r = i === 0 ? 5 : 4, inset = i === 0 ? 1 : 1.5;
                const x = x0 + p.x * c + inset, y = y0 + p.y * c + inset, s = c - inset * 2;
                ctx.beginPath();
                ctx.moveTo(x + r, y);
                ctx.arcTo(x + s, y, x + s, y + s, r);
                ctx.arcTo(x + s, y + s, x, y + s, r);
                ctx.arcTo(x, y + s, x, y, r);
                ctx.arcTo(x, y, x + s, y, r);
                ctx.closePath();
                ctx.fill();
            }
            ctx.globalAlpha = 1;

            ctx.textAlign = "center";
            ctx.fillStyle = ink;
            if (root.phase === "idle") {
                ctx.font = `13px "${Appearance.font.main}"`;
                ctx.fillText(Translation.tr("Nothing new"), width / 2, y0 + 60);
                ctx.fillStyle = faint;
                ctx.font = `12px "${Appearance.font.main}"`;
                ctx.fillText(Translation.tr("Click to play snake"), width / 2, y0 + 82);
            } else if (root.phase === "over") {
                ctx.font = `bold 15px "${Appearance.font.mono}"`;
                ctx.fillText("G A M E   O V E R", width / 2, y0 + 70);
                ctx.fillStyle = faint;
                ctx.font = `12px "${Appearance.font.main}"`;
                ctx.fillText(Translation.tr("Click to try again"), width / 2, y0 + 92);
            }
        }
    }

    // Repaint when the size or the language changes.
    onWidthChanged: canvas.requestPaint()
    onHeightChanged: canvas.requestPaint()
    Connections {
        target: Translation
        function onStringsChanged() {
            canvas.requestPaint();
        }
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onPressed: mouse => {
            if (root.phase !== "playing") {
                root.start();
                return;
            }
            // Turn towards the click: along the axis it's farther from the head on.
            const head = root.snake[0];
            const x0 = (root.width - root.cols * root.cell) / 2;
            const dx = mouse.x - (x0 + (head.x + 0.5) * root.cell);
            const dy = mouse.y - (root.headerHeight + (head.y + 0.5) * root.cell);
            root.turn(Math.abs(dx) > Math.abs(dy) ? (dx > 0 ? 1 : 3) : (dy > 0 ? 2 : 0));
        }
    }

    focus: true
    Keys.onPressed: event => {
        const key = event.key;
        const d = key === Qt.Key_Up || key === Qt.Key_W ? 0 : key === Qt.Key_Right || key === Qt.Key_D ? 1
                : key === Qt.Key_Down || key === Qt.Key_S ? 2 : key === Qt.Key_Left || key === Qt.Key_A ? 3 : -1;
        if (d >= 0) {
            root.turn(d);
            event.accepted = true;
        } else if (key === Qt.Key_Space && root.phase !== "playing") {
            root.start();
            event.accepted = true;
        }
    }

    FileView {
        id: bestFile
        path: `${Paths.state}/snake.txt`
        printErrors: false
        onLoaded: {
            root.best = parseInt(text()) || 0;
            canvas.requestPaint();
        }
    }
}
