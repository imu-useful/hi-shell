import QtQuick
import Quickshell
import Quickshell.Io
import qs.common

// Chrome's offline T-rex game, for the empty notification center. Click (or Space)
// to start; Space / Up / click jumps, Down ducks under pterodactyls. Drawn on a
// Canvas from pixel sprites in the palette's colors; the best score is kept in
// ~/.local/state/hi-shell/dino.txt. Only runs (FrameAnimation) while playing.
Item {
    id: root

    implicitHeight: 150

    // idle | playing | over
    property string phase: "idle"
    property real score: 0
    property int best: 0

    readonly property int px: 2 // canvas pixels per sprite cell
    readonly property real groundY: height - 18

    // --- Sprites ('#' = filled cell) ---
    readonly property var dinoRun: [[
        "           ######## ",
        "          ## #######",
        "          ##########",
        "          ##########",
        "          #####     ",
        "          ########  ",
        "#        #####      ",
        "#      ########     ",
        "##    ########## #  ",
        "###  ##########     ",
        "#############       ",
        " ###########        ",
        "  #########         ",
        "   #######          ",
        "    ##  ###         ",
        "    #               ",
        "    ##              "
    ], [
        "           ######## ",
        "          ## #######",
        "          ##########",
        "          ##########",
        "          #####     ",
        "          ########  ",
        "#        #####      ",
        "#      ########     ",
        "##    ########## #  ",
        "###  ##########     ",
        "#############       ",
        " ###########        ",
        "  #########         ",
        "   #######          ",
        "    ###  ##         ",
        "          #         ",
        "          ##        "
    ]]
    readonly property var dinoDead: [
        "           ######## ",
        "          # # ######",
        "          ## #######",
        "          # # ######",
        "          #####     ",
        "          ########  ",
        "#        #####      ",
        "#      ########     ",
        "##    ########## #  ",
        "###  ##########     ",
        "#############       ",
        " ###########        ",
        "  #########         ",
        "   #######          ",
        "    ##  ##          ",
        "    #   #           ",
        "    ##  ##          "
    ]
    readonly property var dinoDuck: [[
        "#        ########## ######## ",
        "##  ################# #######",
        " #################### ######",
        "  ##########################",
        "   ##########  ######       ",
        "    ##  ###                 ",
        "    #                       ",
        "    ##                      "
    ], [
        "#        ########## ######## ",
        "##  ################# #######",
        " #################### ######",
        "  ##########################",
        "   ##########  ######       ",
        "    ###  ##                 ",
        "          #                 ",
        "          ##                "
    ]]
    readonly property var cactusSmall: [
        "   ##   ",
        "   ## # ",
        "#  ## # ",
        "#  ## # ",
        "#  ####  ",
        "####    ",
        "   ##   ",
        "   ##   ",
        "   ##   ",
        "   ##   ",
        "   ##   "
    ]
    readonly property var cactusLarge: [
        "    ##    ",
        "    ##    ",
        "    ## ## ",
        "##  ## ## ",
        "##  ## ## ",
        "##  ## ## ",
        "##  #####  ",
        "##  ##    ",
        "######    ",
        "    ##    ",
        "    ##    ",
        "    ##    ",
        "    ##    ",
        "    ##    ",
        "    ##    "
    ]
    readonly property var bird: [[
        "    #           ",
        "   ##           ",
        "  ###  #        ",
        " ####  ##       ",
        "################",
        "     ########   ",
        "      ######    "
    ], [
        "                ",
        "                ",
        "        ##      ",
        " ###############",
        "################",
        "     #######    ",
        "       ##       "
    ]]

    // --- Game state ---
    property real dinoY: 0 // height above the ground (px)
    property real dinoVy: 0
    property bool ducking: false
    property real speed: 260 // px / s
    property real time: 0
    property real nextGap: 300
    property real groundOffset: 0
    property var obstacles: [] // { kind, x, y (above ground), sprite }

    function spriteSize(sprite) {
        return { w: sprite[0].length * px, h: sprite.length * px };
    }

    function start() {
        phase = "playing";
        score = 0;
        time = 0;
        speed = 260;
        dinoY = 0;
        dinoVy = 0;
        ducking = false;
        obstacles = [];
        nextGap = 260;
        forceActiveFocus();
    }

    function jump() {
        if (phase !== "playing") {
            start();
            return;
        }
        if (dinoY === 0 && !ducking)
            dinoVy = 640;
    }

    function gameOver() {
        phase = "over";
        const s = Math.floor(score);
        if (s > best) {
            best = s;
            bestFile.setText(String(best) + "\n");
        }
        canvas.requestPaint();
    }

    function spawn() {
        const roll = Math.random();
        if (score > 250 && roll < 0.25) {
            // Pterodactyl: low (jump), middle (duck or jump) or high (duck... or run under).
            const heights = [8, 34, 60];
            obstacles.push({ kind: "bird", x: width + 10, y: heights[Math.floor(Math.random() * 3)] });
        } else {
            const large = Math.random() < 0.4;
            const count = 1 + Math.floor(Math.random() * (speed > 380 ? 3 : 2));
            const sprite = large ? cactusLarge : cactusSmall;
            for (let i = 0; i < count; i++)
                obstacles.push({ kind: "cactus", x: width + 10 + i * (spriteSize(sprite).w + 2), y: 0, sprite });
        }
        nextGap = speed * (0.75 + Math.random() * 0.9);
    }

    function step(dt) {
        dt = Math.min(dt, 0.05);
        time += dt;
        speed = Math.min(720, speed + 9 * dt);
        score += speed * dt * 0.04;

        // Dino physics
        if (dinoY > 0 || dinoVy > 0) {
            dinoVy -= (ducking ? 4200 : 2100) * dt;
            dinoY = Math.max(0, dinoY + dinoVy * dt);
            if (dinoY === 0)
                dinoVy = 0;
        }

        // World
        const dx = speed * dt;
        groundOffset = (groundOffset + dx) % 24;
        for (const o of obstacles)
            o.x -= o.kind === "bird" ? dx * 1.15 : dx;
        obstacles = obstacles.filter(o => o.x > -60);
        nextGap -= dx;
        if (nextGap <= 0)
            spawn();

        // Collision (boxes slightly inside the sprites)
        const d = dinoBox();
        for (const o of obstacles) {
            const sprite = o.kind === "bird" ? bird[0] : o.sprite;
            const s = spriteSize(sprite);
            const box = { x: o.x + 4, y: groundY - o.y - s.h + 4, w: s.w - 8, h: s.h - 6 };
            if (d.x < box.x + box.w && d.x + d.w > box.x && d.y < box.y + box.h && d.y + d.h > box.y) {
                gameOver();
                return;
            }
        }
        canvas.requestPaint();
    }

    function dinoSprite() {
        if (phase === "over")
            return dinoDead;
        if (phase !== "playing")
            return dinoRun[0];
        const frame = Math.floor(time * 10) % 2;
        if (ducking && dinoY === 0)
            return dinoDuck[frame];
        return dinoY > 0 ? dinoRun[0] : dinoRun[frame];
    }

    function dinoBox() {
        const s = spriteSize(dinoSprite());
        return { x: 24 + 6, y: groundY - dinoY - s.h + 4, w: s.w - 14, h: s.h - 8 };
    }

    FrameAnimation {
        running: root.phase === "playing" && root.visible
        onTriggered: root.step(frameTime)
    }

    Canvas {
        id: canvas
        anchors.fill: parent

        readonly property color ink: Colors.m3onSurfaceVariant
        readonly property color accent: Colors.m3primary
        readonly property color faint: Colors.m3outlineVariant

        function sprite(ctx, rows, x, y, color) {
            ctx.fillStyle = color;
            const p = root.px;
            for (let r = 0; r < rows.length; r++) {
                const row = rows[r];
                for (let c = 0; c < row.length; c++) {
                    if (row[c] === "#")
                        ctx.fillRect(Math.round(x + c * p), Math.round(y + r * p), p, p);
                }
            }
        }

        onInkChanged: requestPaint()
        onAccentChanged: requestPaint()

        onPaint: {
            const ctx = getContext("2d");
            ctx.reset();
            const w = width, g = root.groundY;

            // Ground with scrolling bumps
            ctx.fillStyle = faint;
            ctx.fillRect(0, g, w, 1);
            for (let x = -root.groundOffset; x < w; x += 24)
                ctx.fillRect(Math.round(x), g + 4, 3, 1), ctx.fillRect(Math.round(x + 11), g + 7, 2, 1);

            // Obstacles
            for (const o of root.obstacles) {
                const rows = o.kind === "bird" ? root.bird[Math.floor(root.time * 6) % 2] : o.sprite;
                sprite(ctx, rows, o.x, g - o.y - rows.length * root.px, ink);
            }

            // Dino
            const rows = root.dinoSprite();
            sprite(ctx, rows, 24, g - root.dinoY - rows.length * root.px + 1, accent);

            // Score
            ctx.fillStyle = ink;
            ctx.font = `bold 12px "${Appearance.font.mono}"`;
            ctx.textAlign = "right";
            const pad = n => String(n).padStart(5, "0");
            ctx.fillText(`HI ${pad(root.best)}  ${pad(Math.floor(root.score))}`, w - 8, 16);

            ctx.textAlign = "center";
            if (root.phase === "idle") {
                ctx.font = `13px "${Appearance.font.main}"`;
                ctx.fillText(Translation.tr("Nothing new"), w / 2, 46);
                ctx.fillStyle = faint;
                ctx.font = `12px "${Appearance.font.main}"`;
                ctx.fillText(Translation.tr("Click the dino to play"), w / 2, 66);
            } else if (root.phase === "over") {
                ctx.font = `bold 15px "${Appearance.font.mono}"`;
                ctx.fillText("G A M E   O V E R", w / 2, 50);
                ctx.fillStyle = faint;
                ctx.font = `12px "${Appearance.font.main}"`;
                ctx.fillText(Translation.tr("Space or click to try again"), w / 2, 70);
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
        onPressed: root.jump()
    }

    focus: true
    Keys.onPressed: event => {
        if (event.key === Qt.Key_Space || event.key === Qt.Key_Up || event.key === Qt.Key_W) {
            if (!event.isAutoRepeat)
                root.jump();
            event.accepted = true;
        } else if (event.key === Qt.Key_Down || event.key === Qt.Key_S) {
            if (root.phase === "playing")
                root.ducking = true;
            event.accepted = true;
        }
    }
    Keys.onReleased: event => {
        if (event.key === Qt.Key_Down || event.key === Qt.Key_S) {
            root.ducking = false;
            event.accepted = true;
        }
    }

    FileView {
        id: bestFile
        path: `${Paths.state}/dino.txt`
        printErrors: false
        onLoaded: {
            root.best = parseInt(text()) || 0;
            canvas.requestPaint();
        }
    }
}
