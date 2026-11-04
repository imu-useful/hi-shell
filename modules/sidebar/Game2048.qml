import QtQuick
import Quickshell
import Quickshell.Io
import qs.common
import qs.common.widgets

// 2048, for the empty notification center. Arrow keys / WASD, or drag (swipe) on the board, slide the
// tiles; equal ones that meet add up. The icon in the corner (or a click once it is over) starts again.
// The best score is kept in ~/.local/state/hi-shell/2048.txt.
Item {
    id: root

    readonly property int gap: 6
    readonly property int headerHeight: 34
    readonly property real boardSize: Math.min(width - 16, 300)
    readonly property real cell: (boardSize - gap * 5) / 4

    implicitHeight: headerHeight + boardSize + 12

    property var board: new Array(16).fill(0)
    property int score: 0
    property int best: 0
    property bool over: false

    // Tile colors: the primary, stronger with every doubling.
    function tileColor(v) {
        const level = Math.log2(v);
        return Qt.alpha(Colors.m3primary, Math.min(1, 0.12 + level * 0.075));
    }

    function spawn() {
        const free = [];
        for (let i = 0; i < 16; i++) {
            if (board[i] === 0)
                free.push(i);
        }
        if (free.length === 0)
            return;
        const next = board.slice();
        next[free[Math.floor(Math.random() * free.length)]] = Math.random() < 0.9 ? 2 : 4;
        board = next;
    }

    function newGame() {
        board = new Array(16).fill(0);
        score = 0;
        over = false;
        spawn();
        spawn();
        forceActiveFocus();
    }

    // The cell indexes of line `k`, ordered from the wall the tiles slide to. dir: 0 up, 1 right, 2 down, 3 left.
    function line(dir, k) {
        const out = [];
        for (let i = 0; i < 4; i++) {
            const r = dir === 0 ? i : dir === 2 ? 3 - i : k;
            const c = dir === 3 ? i : dir === 1 ? 3 - i : k;
            out.push(r * 4 + c);
        }
        return out;
    }

    function canMove(b) {
        for (let i = 0; i < 16; i++) {
            if (b[i] === 0)
                return true;
            if (i % 4 < 3 && b[i] === b[i + 1])
                return true;
            if (i < 12 && b[i] === b[i + 4])
                return true;
        }
        return false;
    }

    function move(dir) {
        if (over)
            return;
        const next = board.slice();
        let gained = 0;
        for (let k = 0; k < 4; k++) {
            const idx = line(dir, k);
            const values = idx.map(i => next[i]).filter(v => v !== 0);
            const merged = [];
            for (let i = 0; i < values.length; i++) {
                if (i + 1 < values.length && values[i] === values[i + 1]) {
                    merged.push(values[i] * 2);
                    gained += values[i] * 2;
                    i++;
                } else {
                    merged.push(values[i]);
                }
            }
            idx.forEach((cellIndex, i) => next[cellIndex] = merged[i] ?? 0);
        }
        if (next.every((v, i) => v === board[i]))
            return;
        board = next;
        score += gained;
        spawn();
        if (score > best) {
            best = score;
            bestFile.setText(String(best) + "\n");
        }
        if (!canMove(board))
            over = true;
    }

    Component.onCompleted: newGame()

    // Header: the name, the scores, a new game.
    Row {
        anchors.left: parent.left
        anchors.leftMargin: 8
        y: 4
        spacing: 8
        StyledText {
            text: "2048"
            font.pixelSize: Appearance.font.size.titleMedium
            font.weight: Font.Bold
            color: Colors.m3primary
        }
    }
    Row {
        anchors.right: parent.right
        anchors.rightMargin: 8
        y: 6
        spacing: 12

        StyledText {
            text: `${Translation.tr("Best")} ${root.best}   ${Translation.tr("Score")} ${root.score}`
            font.family: Appearance.font.mono
            font.pixelSize: Appearance.font.size.labelMedium
            color: Colors.m3onSurfaceVariant
            anchors.verticalCenter: parent.verticalCenter
        }
        MaterialIcon {
            icon: "refresh"
            iconSize: 20
            anchors.verticalCenter: parent.verticalCenter
            MouseArea {
                anchors.fill: parent
                anchors.margins: -6
                cursorShape: Qt.PointingHandCursor
                onClicked: root.newGame()
            }
        }
    }

    Rectangle {
        id: boardView
        x: (parent.width - width) / 2
        y: root.headerHeight
        width: root.boardSize
        height: root.boardSize
        radius: 12
        color: Colors.m3surfaceContainerHigh

        Repeater {
            model: 16

            Rectangle {
                id: tile

                required property int index
                readonly property int value: root.board[index]

                x: root.gap + (index % 4) * (root.cell + root.gap)
                y: root.gap + Math.floor(index / 4) * (root.cell + root.gap)
                width: root.cell
                height: root.cell
                radius: 8
                color: value > 0 ? root.tileColor(value) : Qt.alpha(Colors.m3onSurface, 0.06)
                Behavior on color { ColorAnim {} }

                // A new or merged tile pops.
                onValueChanged: if (value > 0) pop.restart()
                SequentialAnimation {
                    id: pop
                    NumberAnimation { target: tile; property: "scale"; from: 0.72; to: 1; duration: Appearance.anim.normal; easing.type: Easing.OutBack; easing.overshoot: 2.2 }
                }

                StyledText {
                    anchors.centerIn: parent
                    visible: tile.value > 0
                    text: tile.value
                    font.weight: Font.Bold
                    font.pixelSize: tile.value >= 1024 ? 15 : tile.value >= 128 ? 18 : 22
                    color: tile.value >= 16 ? Colors.m3onPrimary : Colors.m3onSurface
                }
            }
        }

        // The game is over.
        Rectangle {
            anchors.fill: parent
            radius: parent.radius
            visible: root.over
            color: Qt.alpha(Colors.m3surface, 0.8)
            StyledText {
                anchors.centerIn: parent
                horizontalAlignment: Text.AlignHCenter
                text: `${Translation.tr("No moves left")}\n${Translation.tr("Click to try again")}`
                font.weight: Font.Medium
                color: Colors.m3onSurface
            }
        }
    }

    // Drag to slide; a click focuses (for the keys), and starts again when it is over.
    MouseArea {
        anchors.fill: boardView
        property point from
        onPressed: mouse => {
            from = Qt.point(mouse.x, mouse.y);
            root.forceActiveFocus();
        }
        onReleased: mouse => {
            const dx = mouse.x - from.x, dy = mouse.y - from.y;
            if (Math.max(Math.abs(dx), Math.abs(dy)) < 18) {
                if (root.over)
                    root.newGame();
                return;
            }
            root.move(Math.abs(dx) > Math.abs(dy) ? (dx > 0 ? 1 : 3) : (dy > 0 ? 2 : 0));
        }
    }

    focus: true
    Keys.onPressed: event => {
        const key = event.key;
        const d = key === Qt.Key_Up || key === Qt.Key_W ? 0 : key === Qt.Key_Right || key === Qt.Key_D ? 1
                : key === Qt.Key_Down || key === Qt.Key_S ? 2 : key === Qt.Key_Left || key === Qt.Key_A ? 3 : -1;
        if (d >= 0) {
            root.move(d);
            event.accepted = true;
        }
    }

    FileView {
        id: bestFile
        path: `${Paths.state}/2048.txt`
        printErrors: false
        onLoaded: root.best = parseInt(text()) || 0
    }
}
