import QtQuick
import QtMultimedia
import Quickshell
import Quickshell.Io
import qs.common
import qs.common.widgets

// Keys "mania" and "osu": a four-lane rhythm game. Notes fall onto the line; press D F J K as they
// land (hold the long ones to the end). The song and the chart come from tools/make_secret_music.py.
// R restarts, Esc closes.
Item {
    id: root

    required property bool revealed

    readonly property real travel: 1.1 // seconds a note takes from the top to the line
    readonly property var windows: [0.045, 0.09, 0.135] // Perfect, Great, Good (seconds either side)
    readonly property real missAfter: 0.135
    readonly property var judgeNames: [Translation.tr("Perfect"), Translation.tr("Great"), Translation.tr("Good"), Translation.tr("Miss")]
    readonly property var judgeColors: ["#ffd75e", "#7ee787", "#79c0ff", "#ff6b6b"]
    readonly property var judgeWeights: [1, 0.8, 0.5, 0]
    readonly property var laneColors: ["#ff6b9d", "#5cc8ff", "#7ee787", "#ffb347"]
    readonly property var laneKeys: ["D", "F", "J", "K"]
    // evdev codes + 8: the keys work on any layout (Cyrillic too)
    readonly property var scanCodes: [40, 41, 44, 45]

    property var notes: []
    property real length: 0
    property real song: 0
    property int score: 0
    property int combo: 0
    property int maxCombo: 0
    property var counts: [0, 0, 0, 0]
    property bool over: false
    property string judgeText: ""
    property color judgeColor: "white"
    property real judgeAge: 10
    property var pressedAt: [-10, -10, -10, -10]
    property var held: [false, false, false, false]
    property real basePos: 0
    property real baseWall: 0

    readonly property int judged: counts[0] + counts[1] + counts[2] + counts[3]
    readonly property real accuracy: judged > 0 ? (counts[0] + counts[1] * 0.8 + counts[2] * 0.5) / judged : 1
    readonly property string grade: accuracy >= 0.95 ? "S" : accuracy >= 0.9 ? "A" : accuracy >= 0.8 ? "B" : accuracy >= 0.7 ? "C" : "D"

    FileView {
        id: chartFile
        path: Quickshell.shellPath("sounds/secret/mania.json")
        blockLoading: true
    }

    AudioOutput { id: audio }

    MediaPlayer {
        id: player
        source: Qt.resolvedUrl("../../sounds/secret/mania.ogg")
        audioOutput: audio
        onMediaStatusChanged: if (mediaStatus === MediaPlayer.EndOfMedia) root.over = true
    }

    function now(): real {
        return Date.now() / 1000;
    }

    function start() {
        let chart;
        try {
            chart = JSON.parse(chartFile.text());
        } catch (e) {
            console.warn("mania: no chart", e);
            return;
        }
        length = chart.length;
        notes = chart.notes.map(n => ({ t: n[0], l: n[1], d: n[2], state: 0, grade: 0 }));
        song = 0; basePos = 0; baseWall = now();
        score = 0; combo = 0; maxCombo = 0; counts = [0, 0, 0, 0];
        over = false; judgeAge = 10;
        held = [false, false, false, false];
        player.stop();
        player.play();
    }

    Component.onCompleted: {
        forceActiveFocus();
        start();
    }

    function setJudge(g) {
        judgeText = judgeNames[g];
        judgeColor = judgeColors[g];
        judgeAge = 0;
    }

    function count(g) {
        const c = counts.slice();
        c[g]++;
        counts = c;
        if (g === 3) {
            combo = 0;
        } else {
            combo++;
            maxCombo = Math.max(maxCombo, combo);
            score += Math.round(1000 * judgeWeights[g] * (1 + Math.min(combo, 50) / 50));
        }
        setJudge(g);
    }

    function press(lane) {
        const p = pressedAt.slice(); p[lane] = song; pressedAt = p;
        const h = held.slice(); h[lane] = true; held = h;
        if (over)
            return;
        for (const n of notes) {
            if (n.l !== lane || n.state !== 0)
                continue;
            if (n.t - song > windows[2])
                return; // the next note is still too far
            if (song - n.t > windows[2])
                continue; // already missed, tick() will mark it
            const diff = Math.abs(n.t - song);
            const g = diff <= windows[0] ? 0 : diff <= windows[1] ? 1 : 2;
            n.grade = g;
            n.state = n.d > 0 ? 3 : 1;
            count(g);
            return;
        }
    }

    function release(lane) {
        const h = held.slice(); h[lane] = false; held = h;
        for (const n of notes) {
            if (n.l === lane && n.state === 3) {
                // Let go before the end: the hold breaks
                n.state = 4;
                if (song < n.t + n.d - 0.12) {
                    combo = 0;
                    setJudge(3);
                } else {
                    score += 300;
                }
            }
        }
    }

    function tick() {
        if (player.playbackState === MediaPlayer.PlayingState) {
            const p = player.position / 1000;
            if (p !== basePos) {
                basePos = p;
                baseWall = now();
            }
            song = basePos + (now() - baseWall);
        }
        judgeAge += 1 / 60;
        for (const n of notes) {
            if (n.state === 0 && song - n.t > missAfter) {
                n.state = 2;
                count(3);
            } else if (n.state === 3 && song >= n.t + n.d) {
                n.state = 4;
                score += 300;
            }
        }
        if (!over && song > length + 1)
            over = true;
        canvas.requestPaint();
    }

    FrameAnimation {
        running: root.revealed
        onTriggered: root.tick()
    }

    function laneOf(event) {
        const byScan = scanCodes.indexOf(event.nativeScanCode);
        if (byScan >= 0)
            return byScan;
        return [[Qt.Key_D, 0x412], [Qt.Key_F, 0x410], [Qt.Key_J, 0x41e], [Qt.Key_K, 0x41b]].findIndex(k => k.includes(event.key));
    }

    Keys.onPressed: event => {
        if (event.isAutoRepeat)
            return;
        if (event.key === Qt.Key_R) {
            start();
            return;
        }
        const lane = laneOf(event);
        if (lane >= 0)
            press(lane);
    }
    Keys.onReleased: event => {
        if (event.isAutoRepeat)
            return;
        const lane = laneOf(event);
        if (lane >= 0)
            release(lane);
    }

    // Clicks do nothing here (a stray one mustn't close the overlay mid-song); Esc closes
    MouseArea {
        anchors.fill: parent
    }

    readonly property real fieldW: Math.min(width * 0.42, height * 0.62)
    readonly property real laneW: fieldW / 4
    readonly property real hitY: height * 0.8

    Canvas {
        id: canvas
        anchors.fill: parent

        function rr(ctx, x, y, w, h, r) {
            r = Math.min(r, w / 2, h / 2);
            ctx.beginPath();
            ctx.moveTo(x + r, y);
            ctx.arcTo(x + w, y, x + w, y + h, r);
            ctx.arcTo(x + w, y + h, x, y + h, r);
            ctx.arcTo(x, y + h, x, y, r);
            ctx.arcTo(x, y, x + w, y, r);
            ctx.closePath();
        }

        onPaint: {
            const ctx = getContext("2d");
            const w = width, h = height, lw = root.laneW, x0 = (w - root.fieldW) / 2, hitY = root.hitY;
            const speed = hitY / root.travel;
            const noteH = lw * 0.3;
            ctx.clearRect(0, 0, w, h);

            // Field
            ctx.fillStyle = "rgba(255, 255, 255, 0.04)";
            ctx.fillRect(x0, 0, root.fieldW, h);
            for (let l = 0; l < 4; l++) {
                const age = root.song - root.pressedAt[l];
                const glow = root.held[l] ? 0.45 : Math.max(0, 0.45 - age * 2.5);
                if (glow > 0) {
                    const g = ctx.createLinearGradient(0, hitY, 0, hitY - h * 0.5);
                    g.addColorStop(0, Qt.rgba(1, 1, 1, 0) + "");
                    ctx.fillStyle = root.laneColors[l];
                    ctx.globalAlpha = glow * 0.5;
                    const grad = ctx.createLinearGradient(0, hitY, 0, hitY - h * 0.45);
                    grad.addColorStop(0, root.laneColors[l]);
                    grad.addColorStop(1, "rgba(0,0,0,0)");
                    ctx.fillStyle = grad;
                    ctx.fillRect(x0 + l * lw, hitY - h * 0.45, lw, h * 0.45);
                    ctx.globalAlpha = 1;
                }
                if (l > 0) {
                    ctx.fillStyle = "rgba(255, 255, 255, 0.12)";
                    ctx.fillRect(x0 + l * lw - 1, 0, 2, h);
                }
            }

            // Notes
            for (const n of root.notes) {
                if (n.state === 1 || n.state === 4 && n.d === 0)
                    continue;
                const y = n.state === 3 ? hitY : hitY - (n.t - root.song) * speed;
                const yEnd = n.d > 0 ? hitY - (n.t + n.d - root.song) * speed : y;
                if (y < -noteH || yEnd > h)
                    continue;
                if (n.state === 4 && yEnd > hitY)
                    continue;
                const missed = n.state === 2;
                const col = missed ? "#555a66" : root.laneColors[n.l];
                const x = x0 + n.l * lw;
                if (n.d > 0) {
                    ctx.globalAlpha = missed ? 0.5 : n.state === 3 ? 0.95 : 0.65;
                    ctx.fillStyle = col;
                    rr(ctx, x + lw * 0.22, yEnd, lw * 0.56, y - yEnd, 8);
                    ctx.fill();
                    ctx.globalAlpha = 1;
                }
                ctx.fillStyle = col;
                rr(ctx, x + 5, y - noteH, lw - 10, noteH, noteH * 0.35);
                ctx.fill();
                ctx.fillStyle = "rgba(255, 255, 255, 0.35)";
                rr(ctx, x + 9, y - noteH + 3, lw - 18, noteH * 0.3, 4);
                ctx.fill();
            }

            // Receptors on the line
            for (let l = 0; l < 4; l++) {
                const down = root.held[l];
                ctx.strokeStyle = root.laneColors[l];
                ctx.lineWidth = down ? 6 : 3;
                ctx.fillStyle = down ? root.laneColors[l] : "rgba(0, 0, 0, 0.55)";
                rr(ctx, x0 + l * lw + 5, hitY - noteH + 4, lw - 10, noteH, noteH * 0.35);
                ctx.fill();
                ctx.stroke();
            }
        }
    }

    // Key names under the line
    Row {
        x: (root.width - root.fieldW) / 2
        y: root.hitY + root.laneW * 0.25
        Repeater {
            model: 4
            StyledText {
                required property int index
                width: root.laneW
                horizontalAlignment: Text.AlignHCenter
                text: root.laneKeys[index]
                font.family: Appearance.font.mono
                font.pixelSize: root.laneW * 0.3
                font.weight: Font.Bold
                color: root.held[index] ? "white" : root.laneColors[index]
            }
        }
    }

    // Combo and the last judgement above the line
    Column {
        anchors.horizontalCenter: parent.horizontalCenter
        y: root.height * 0.28
        spacing: 6
        visible: !root.over
        StyledText {
            anchors.horizontalCenter: parent.horizontalCenter
            text: root.combo > 1 ? root.combo : ""
            font.family: Appearance.font.title
            font.pixelSize: root.laneW * 0.9
            font.weight: Font.Bold
            color: "white"
            opacity: 0.85
            scale: 1 + Math.max(0, 0.25 - root.judgeAge * 1.2)
        }
        StyledText {
            anchors.horizontalCenter: parent.horizontalCenter
            text: root.judgeText
            font.family: Appearance.font.title
            font.pixelSize: root.laneW * 0.32
            font.weight: Font.Bold
            color: root.judgeColor
            opacity: Math.max(0, 1 - root.judgeAge / 0.7)
        }
    }

    // Score and accuracy on the right of the field
    Column {
        x: (root.width + root.fieldW) / 2 + 40
        y: 40
        spacing: 4
        StyledText {
            text: String(root.score).padStart(7, "0")
            font.family: Appearance.font.mono
            font.pixelSize: Math.min(54, root.width / 28)
            font.weight: Font.Bold
            color: "white"
        }
        StyledText {
            text: (root.accuracy * 100).toFixed(2) + "%  ·  " + root.grade
            font.family: Appearance.font.mono
            font.pixelSize: Math.min(24, root.width / 64)
            color: "#aab"
        }
    }

    // Progress
    Rectangle {
        x: 0; y: 0
        width: root.length > 0 ? root.width * Math.min(1, root.song / root.length) : 0
        height: 4
        color: "#7ee787"
    }

    StyledText {
        anchors.left: parent.left
        anchors.bottom: parent.bottom
        anchors.margins: 24
        text: Translation.tr("D F J K to play · R to restart · Esc to close")
        font.family: Appearance.font.mono
        color: "white"
        opacity: 0.4
    }

    // Results
    Rectangle {
        anchors.centerIn: parent
        width: Math.min(root.width * 0.5, 620)
        height: resultColumn.implicitHeight + 80
        radius: 28
        color: "#e6101018"
        border.color: "#44ffffff"
        border.width: 2
        visible: root.over
        scale: root.over ? 1 : 0.8
        Behavior on scale { NumberAnimation { duration: 350; easing.type: Easing.OutBack } }

        Column {
            id: resultColumn
            anchors.centerIn: parent
            spacing: 10
            StyledText {
                anchors.horizontalCenter: parent.horizontalCenter
                text: root.grade
                font.family: Appearance.font.title
                font.pixelSize: 140
                font.weight: Font.Bold
                color: root.grade === "S" ? "#ffd75e" : root.grade === "A" ? "#7ee787" : root.grade === "B" ? "#79c0ff" : "#ff9a9a"
            }
            StyledText {
                anchors.horizontalCenter: parent.horizontalCenter
                text: String(root.score).padStart(7, "0")
                font.family: Appearance.font.mono
                font.pixelSize: 44
                color: "white"
            }
            StyledText {
                anchors.horizontalCenter: parent.horizontalCenter
                text: (root.accuracy * 100).toFixed(2) + "%   ·   " + Translation.tr("Max combo") + " " + root.maxCombo
                font.family: Appearance.font.mono
                font.pixelSize: 22
                color: "#ccd"
            }
            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 22
                Repeater {
                    model: 4
                    StyledText {
                        required property int index
                        text: root.judgeNames[index] + " " + root.counts[index]
                        font.family: Appearance.font.mono
                        font.pixelSize: 18
                        color: root.judgeColors[index]
                    }
                }
            }
            StyledText {
                anchors.horizontalCenter: parent.horizontalCenter
                text: Translation.tr("R to play again · Esc to close")
                font.family: Appearance.font.mono
                font.pixelSize: 16
                color: "white"
                opacity: 0.5
            }
        }
    }
}
