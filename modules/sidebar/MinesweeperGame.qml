import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.common
import qs.common.widgets

// Minesweeper, for the empty notification center. Left click opens a square (on a number whose
// flags are all placed: its neighbors), right click puts a flag; the first click is always safe.
// The face starts a new game. The best winning time is kept in ~/.local/state/hi-shell/minesweeper.txt.
Item {
    id: root

    readonly property int cell: 26
    readonly property int gap: 2
    readonly property int cols: Math.max(8, Math.min(14, Math.floor((width - 8) / (cell + gap))))
    readonly property int rows: 8
    readonly property int mineCount: Math.round(cols * rows * 0.16)

    implicitHeight: 40 + rows * (cell + gap) + 8

    // idle (no mines placed yet) | playing | won | lost
    property string phase: "idle"
    // One entry per square: { mine, count, open, flag, boom }
    property var cells: []
    property int seconds: 0
    // Best winning time (s), 0 = none yet.
    property int best: 0
    readonly property int flags: cells.reduce((n, c) => n + (c.flag ? 1 : 0), 0)

    // The numbers' colors, one per count.
    readonly property var numberColors: [Colors.m3primary, Colors.m3tertiary, Colors.m3error, Colors.m3secondary,
        Colors.m3primary, Colors.m3tertiary, Colors.m3error, Colors.m3secondary]

    function neighbors(i) {
        const x = i % cols, y = Math.floor(i / cols), out = [];
        for (let dy = -1; dy <= 1; dy++) {
            for (let dx = -1; dx <= 1; dx++) {
                const nx = x + dx, ny = y + dy;
                if ((dx !== 0 || dy !== 0) && nx >= 0 && ny >= 0 && nx < cols && ny < rows)
                    out.push(ny * cols + nx);
            }
        }
        return out;
    }

    function newGame() {
        cells = Array.from({ length: cols * rows }, () => ({ mine: false, count: 0, open: false, flag: false, boom: false }));
        seconds = 0;
        phase = "idle";
    }

    // Mines go anywhere but the first square and its neighbors.
    function placeMines(safe) {
        const next = cells.map(c => Object.assign({}, c));
        const banned = new Set([safe, ...neighbors(safe)]);
        const spots = [];
        for (let i = 0; i < next.length; i++) {
            if (!banned.has(i))
                spots.push(i);
        }
        for (let m = 0; m < mineCount && spots.length > 0; m++)
            next[spots.splice(Math.floor(Math.random() * spots.length), 1)[0]].mine = true;
        next.forEach((c, i) => c.count = neighbors(i).filter(n => next[n].mine).length);
        cells = next;
    }

    function open(i) {
        if (phase === "won" || phase === "lost" || cells[i].flag || cells[i].open)
            return;
        if (phase === "idle") {
            placeMines(i);
            phase = "playing";
        }
        const next = cells.map(c => Object.assign({}, c));
        if (next[i].mine) {
            next[i].boom = true;
            next.forEach(c => { if (c.mine) c.open = true; });
            cells = next;
            phase = "lost";
            return;
        }
        // Flood over the empty squares.
        const stack = [i];
        while (stack.length > 0) {
            const j = stack.pop();
            if (next[j].open || next[j].flag)
                continue;
            next[j].open = true;
            if (next[j].count === 0)
                stack.push(...neighbors(j));
        }
        cells = next;
        if (next.every(c => c.mine || c.open))
            win();
    }

    // A number with as many flags around it as it counts: open the rest of its neighbors.
    function chord(i) {
        const c = cells[i];
        if (!c.open || c.count === 0 || phase !== "playing")
            return;
        const around = neighbors(i);
        if (around.filter(n => cells[n].flag).length !== c.count)
            return;
        around.forEach(n => open(n));
    }

    function toggleFlag(i) {
        if (phase === "won" || phase === "lost" || cells[i].open)
            return;
        const next = cells.map(c => Object.assign({}, c));
        next[i].flag = !next[i].flag;
        cells = next;
    }

    function win() {
        phase = "won";
        cells = cells.map(c => Object.assign({}, c, { flag: c.mine }));
        if (best === 0 || seconds < best) {
            best = seconds;
            bestFile.setText(String(best) + "\n");
        }
    }

    Component.onCompleted: newGame()
    // A different width gives a different board.
    onColsChanged: if (phase === "idle") newGame()

    Timer {
        interval: 1000
        running: root.phase === "playing" && root.visible
        repeat: true
        onTriggered: root.seconds++
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 4
        spacing: 8

        // Mines left, the face, the time (and the best one).
        RowLayout {
            Layout.fillWidth: true
            Layout.preferredHeight: 32
            spacing: 8

            StyledText {
                Layout.fillWidth: true
                text: `${Translation.tr("Mines")}  ${String(Math.max(0, root.mineCount - root.flags)).padStart(2, "0")}`
                font.family: Appearance.font.mono
                font.weight: Font.Bold
                color: Colors.m3onSurfaceVariant
            }
            IconButton {
                implicitWidth: 32
                implicitHeight: 32
                icon: root.phase === "won" ? "sentiment_very_satisfied" : root.phase === "lost" ? "sentiment_very_dissatisfied" : "sentiment_satisfied"
                filled: root.phase !== "playing" && root.phase !== "idle"
                tooltip: Translation.tr("New game")
                onClicked: root.newGame()
            }
            StyledText {
                Layout.fillWidth: true
                horizontalAlignment: Text.AlignRight
                text: (root.best > 0 ? `${Translation.tr("Best")} ${root.best}  ` : "") + String(root.seconds).padStart(3, "0")
                font.family: Appearance.font.mono
                font.weight: Font.Bold
                color: Colors.m3onSurfaceVariant
            }
        }

        Grid {
            Layout.alignment: Qt.AlignHCenter
            columns: root.cols
            spacing: root.gap

            Repeater {
                model: root.cells

                Rectangle {
                    id: square

                    required property var modelData
                    required property int index

                    width: root.cell
                    height: root.cell
                    radius: 6
                    color: modelData.boom ? Colors.m3errorContainer
                         : modelData.open ? Colors.m3surfaceContainerLow : Colors.m3surfaceContainerHighest
                    Behavior on color { ColorAnim {} }

                    StyledText {
                        anchors.centerIn: parent
                        visible: square.modelData.open && !square.modelData.mine && square.modelData.count > 0
                        text: square.modelData.count
                        font.weight: Font.Bold
                        color: root.numberColors[square.modelData.count - 1] ?? Colors.m3onSurface
                    }
                    MaterialIcon {
                        anchors.centerIn: parent
                        visible: square.modelData.flag && !square.modelData.open
                        icon: "flag"
                        iconSize: 16
                        fill: 1
                        color: Colors.m3error
                    }
                    MaterialIcon {
                        anchors.centerIn: parent
                        visible: square.modelData.open && square.modelData.mine
                        icon: "bomb"
                        iconSize: 16
                        fill: 1
                        color: square.modelData.boom ? Colors.m3onErrorContainer : Colors.m3onSurfaceVariant
                    }

                    MouseArea {
                        anchors.fill: parent
                        acceptedButtons: Qt.LeftButton | Qt.RightButton
                        hoverEnabled: true
                        cursorShape: square.modelData.open ? Qt.ArrowCursor : Qt.PointingHandCursor

                        Rectangle {
                            anchors.fill: parent
                            radius: square.radius
                            color: Colors.m3onSurface
                            opacity: parent.containsMouse && !square.modelData.open ? 0.08 : 0
                        }
                        onClicked: mouse => {
                            if (mouse.button === Qt.RightButton)
                                root.toggleFlag(square.index);
                            else if (square.modelData.open)
                                root.chord(square.index);
                            else
                                root.open(square.index);
                        }
                    }
                }
            }
        }
    }

    FileView {
        id: bestFile
        path: `${Paths.state}/minesweeper.txt`
        printErrors: false
        onLoaded: root.best = parseInt(text()) || 0
    }
}
