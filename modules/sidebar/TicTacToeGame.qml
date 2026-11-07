import QtQuick
import qs.common
import qs.common.widgets

// Tic-tac-toe, for the empty notification center: you play X against an unbeatable-ish O
// (it wins, blocks, then takes the center, a corner, a side). The score of the session is kept
// in the header; the icon in the corner starts a new round.
Item {
    id: root

    readonly property int gap: 8
    readonly property int headerHeight: 34
    readonly property real boardSize: Math.min(width - 16, 300)
    readonly property real cell: (boardSize - gap * 2) / 3
    readonly property var lines: [[0, 1, 2], [3, 4, 5], [6, 7, 8], [0, 3, 6], [1, 4, 7], [2, 5, 8], [0, 4, 8], [2, 4, 6]]

    implicitHeight: headerHeight + boardSize + 12

    // 9 entries: "", "X" or "O"
    property var board: []
    // "" = running, "X" / "O" = winner, "draw"
    property string result: ""
    property var winLine: []
    property int wins: 0
    property int losses: 0
    property int draws: 0

    function newGame() {
        board = Array(9).fill("");
        result = "";
        winLine = [];
        reply.stop();
    }

    function check(b) {
        for (const l of lines) {
            if (b[l[0]] !== "" && b[l[0]] === b[l[1]] && b[l[0]] === b[l[2]])
                return { who: b[l[0]], line: l };
        }
        return b.includes("") ? null : { who: "draw", line: [] };
    }

    function finish(r) {
        result = r.who;
        winLine = r.line;
        if (r.who === "X")
            wins++;
        else if (r.who === "O")
            losses++;
        else
            draws++;
    }

    function place(i, who) {
        const next = board.slice();
        next[i] = who;
        board = next;
        const r = check(next);
        if (r)
            finish(r);
        return r !== null;
    }

    // A cell that completes a line for `who`, or -1.
    function completing(who) {
        for (const l of lines) {
            const marks = l.filter(i => board[i] === who).length;
            const empty = l.filter(i => board[i] === "");
            if (marks === 2 && empty.length === 1)
                return empty[0];
        }
        return -1;
    }

    function aiMove() {
        let m = completing("O");
        if (m < 0)
            m = completing("X");
        if (m < 0 && board[4] === "")
            m = 4;
        if (m < 0) {
            const corners = [0, 2, 6, 8].filter(i => board[i] === "");
            if (corners.length > 0)
                m = corners[Math.floor(Math.random() * corners.length)];
        }
        if (m < 0)
            m = board.findIndex(c => c === "");
        place(m, "O");
    }

    function play(i) {
        if (result !== "" || board[i] !== "" || reply.running)
            return;
        if (!place(i, "X"))
            reply.restart();
    }

    Timer {
        id: reply
        interval: 350
        onTriggered: root.aiMove()
    }

    Component.onCompleted: newGame()

    StyledText {
        x: 8
        y: 4
        text: Translation.tr("Tic-tac-toe")
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
            text: `${root.wins} : ${root.draws} : ${root.losses}`
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

        Repeater {
            model: 9

            Rectangle {
                id: tile

                required property int index
                readonly property string mark: root.board[index] ?? ""
                readonly property bool winning: root.winLine.includes(index)

                x: (index % 3) * (root.cell + root.gap)
                y: Math.floor(index / 3) * (root.cell + root.gap)
                width: root.cell
                height: root.cell
                radius: 10
                color: winning ? Colors.m3primaryContainer : Colors.m3surfaceContainerHigh
                Behavior on color { ColorAnim {} }

                MaterialIcon {
                    anchors.centerIn: parent
                    icon: tile.mark === "X" ? "close" : tile.mark === "O" ? "circle" : ""
                    fill: 0
                    iconSize: root.cell * 0.6
                    color: tile.mark === "X" ? Colors.m3primary : Colors.m3tertiary
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.play(tile.index)
                }
            }
        }

        Rectangle {
            anchors.fill: parent
            visible: root.result !== ""
            radius: 10
            color: Qt.alpha(Colors.m3surface, 0.82)
            StyledText {
                anchors.centerIn: parent
                horizontalAlignment: Text.AlignHCenter
                text: `${root.result === "X" ? Translation.tr("You won") : root.result === "O" ? Translation.tr("You lost") : Translation.tr("Draw")}\n${Translation.tr("Click to play again")}`
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
}
