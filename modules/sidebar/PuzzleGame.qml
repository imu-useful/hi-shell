import QtQuick
import Quickshell
import Quickshell.Io
import qs.common
import qs.common.widgets

// The 15 puzzle, for the empty notification center: slide the tiles into order. Click a tile in
// the row or column of the gap to shift it. The icon in the corner shuffles again. The fewest
// moves are kept in ~/.local/state/hi-shell/puzzle.txt.
Item {
    id: root

    readonly property int size: 4
    readonly property int gap: 6
    readonly property int headerHeight: 34
    readonly property real boardSize: Math.min(width - 16, 300)
    readonly property real cell: (boardSize - gap * (size - 1)) / size

    implicitHeight: headerHeight + boardSize + 12

    // tiles[position] = tile number 1..15, 0 = the gap
    property var tiles: []
    property int moves: 0
    property int best: 0
    property bool started: false
    readonly property bool won: started && tiles.length > 0 && tiles.every((t, i) => t === (i + 1) % (size * size))

    function newGame() {
        const n = size * size;
        let t = [...Array(n).keys()].map(i => (i + 1) % n);
        // Shuffle by random legal moves: always solvable.
        let gapPos = n - 1;
        let last = -1;
        for (let k = 0; k < 200; k++) {
            const gx = gapPos % size, gy = Math.floor(gapPos / size);
            const options = [];
            if (gx > 0) options.push(gapPos - 1);
            if (gx < size - 1) options.push(gapPos + 1);
            if (gy > 0) options.push(gapPos - size);
            if (gy < size - 1) options.push(gapPos + size);
            const choices = options.filter(p => p !== last);
            const p = choices[Math.floor(Math.random() * choices.length)];
            t[gapPos] = t[p];
            t[p] = 0;
            last = gapPos;
            gapPos = p;
        }
        tiles = t;
        moves = 0;
        started = true;
    }

    function slide(pos) {
        if (won)
            return;
        const gapPos = tiles.indexOf(0);
        const px = pos % size, py = Math.floor(pos / size);
        const gx = gapPos % size, gy = Math.floor(gapPos / size);
        if (pos === gapPos || (px !== gx && py !== gy))
            return;
        const step = px === gx ? (gy > py ? size : -size) : (gx > px ? 1 : -1);
        const next = tiles.slice();
        for (let p = gapPos; p !== pos; p -= step)
            next[p] = next[p - step];
        next[pos] = 0;
        tiles = next;
        moves++;
        if (won && (best === 0 || moves < best)) {
            best = moves;
            bestFile.setText(String(best) + "\n");
        }
    }

    Component.onCompleted: newGame()

    StyledText {
        x: 8
        y: 4
        text: Translation.tr("15 puzzle")
        font.pixelSize: Appearance.font.size.titleMedium
        font.weight: Font.Bold
        color: Colors.m3primary
    }
    Row {
        anchors.right: parent.right
        anchors.rightMargin: 8
        y: 6
        spacing: 12

        StyledText {
            text: `${Translation.tr("Best")} ${root.best || "-"}   ${Translation.tr("Moves")} ${root.moves}`
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

    Item {
        x: (parent.width - width) / 2
        y: root.headerHeight
        width: root.boardSize
        height: root.boardSize

        // One item per tile number, moving to its position.
        Repeater {
            model: root.size * root.size - 1

            Rectangle {
                id: tile

                required property int index
                readonly property int number: index + 1
                readonly property int pos: root.tiles.indexOf(number)
                readonly property bool home: pos === index

                x: (pos % root.size) * (root.cell + root.gap)
                y: Math.floor(pos / root.size) * (root.cell + root.gap)
                width: root.cell
                height: root.cell
                radius: 10
                color: home ? Colors.m3primaryContainer : Colors.m3secondaryContainer
                Behavior on x { NumberAnimation { duration: Appearance.anim.fast; easing.type: Easing.OutCubic } }
                Behavior on y { NumberAnimation { duration: Appearance.anim.fast; easing.type: Easing.OutCubic } }
                Behavior on color { ColorAnim {} }

                StyledText {
                    anchors.centerIn: parent
                    text: tile.number
                    font.pixelSize: root.cell * 0.4
                    font.weight: Font.Bold
                    color: tile.home ? Colors.m3onPrimaryContainer : Colors.m3onSecondaryContainer
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.slide(tile.pos)
                }
            }
        }

        Rectangle {
            anchors.fill: parent
            visible: root.won
            radius: 10
            color: Qt.alpha(Colors.m3surface, 0.82)
            StyledText {
                anchors.centerIn: parent
                horizontalAlignment: Text.AlignHCenter
                text: `${Translation.tr("Solved in %1 moves").arg(root.moves)}\n${Translation.tr("Click to play again")}`
                font.weight: Font.Medium
                color: Colors.m3onSurface
            }
            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: root.newGame()
            }
        }
    }

    FileView {
        id: bestFile
        path: `${Paths.state}/puzzle.txt`
        printErrors: false
        onLoaded: root.best = parseInt(text()) || 0
    }
}
