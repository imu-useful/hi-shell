import QtQuick
import Quickshell
import Quickshell.Io
import qs.common
import qs.common.widgets

// Memory, for the empty notification center: sixteen cards face down, find the eight pairs in the fewest
// moves. The icon in the corner deals again. The fewest moves are kept in ~/.local/state/hi-shell/memory.txt.
Item {
    id: root

    readonly property int gap: 8
    readonly property int headerHeight: 34
    readonly property real boardSize: Math.min(width - 16, 300)
    readonly property real cell: (boardSize - gap * 3) / 4
    readonly property var symbols: ["favorite", "star", "bolt", "pets", "cloud", "rocket_launch", "music_note", "local_fire_department"]

    implicitHeight: headerHeight + boardSize + 12

    // One entry per card: { icon, up, done }
    property var cards: []
    // The face-up cards that are not a pair yet (at most two).
    property var turned: []
    property bool busy: false
    property int moves: 0
    // Fewest moves for a won game, 0 = none yet.
    property int best: 0
    readonly property int pairs: cards.filter(c => c.done).length / 2
    readonly property bool won: cards.length > 0 && pairs === symbols.length

    function newGame() {
        const icons = [...symbols, ...symbols];
        for (let i = icons.length - 1; i > 0; i--) {
            const j = Math.floor(Math.random() * (i + 1));
            [icons[i], icons[j]] = [icons[j], icons[i]];
        }
        cards = icons.map(icon => ({ icon, up: false, done: false }));
        turned = [];
        busy = false;
        moves = 0;
    }

    function flip(i) {
        if (busy || won || cards[i].up || cards[i].done)
            return;
        const next = cards.slice();
        next[i] = { icon: next[i].icon, up: true, done: false };
        cards = next;
        turned = [...turned, i];
        if (turned.length < 2)
            return;
        moves++;
        const [a, b] = turned;
        if (cards[a].icon === cards[b].icon) {
            const done = cards.slice();
            done[a] = { icon: done[a].icon, up: true, done: true };
            done[b] = { icon: done[b].icon, up: true, done: true };
            cards = done;
            turned = [];
            if (won && (best === 0 || moves < best)) {
                best = moves;
                bestFile.setText(String(best) + "\n");
            }
        } else {
            busy = true;
            back.restart();
        }
    }

    Timer {
        id: back
        interval: 750
        onTriggered: {
            const next = root.cards.slice();
            for (const i of root.turned)
                next[i] = { icon: next[i].icon, up: false, done: false };
            root.cards = next;
            root.turned = [];
            root.busy = false;
        }
    }

    Component.onCompleted: newGame()

    StyledText {
        x: 8
        y: 4
        text: Translation.tr("Memory")
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

        Repeater {
            model: root.cards.length

            Rectangle {
                id: card

                required property int index
                readonly property var info: root.cards[index]
                readonly property bool shown: info.up || info.done

                x: (index % 4) * (root.cell + root.gap)
                y: Math.floor(index / 4) * (root.cell + root.gap)
                width: root.cell
                height: root.cell
                radius: 10
                color: info.done ? Colors.m3primaryContainer : shown ? Colors.m3secondaryContainer : Colors.m3surfaceContainerHigh
                Behavior on color { ColorAnim {} }

                // Turns over: it narrows to a line and widens again with the other side.
                transform: Scale {
                    origin.x: card.width / 2
                    xScale: card.xTurn
                }
                property real xTurn: 1
                onShownChanged: turn.restart()
                SequentialAnimation {
                    id: turn
                    NumberAnimation { target: card; property: "xTurn"; to: 0.05; duration: Appearance.anim.fast / 2 }
                    NumberAnimation { target: card; property: "xTurn"; to: 1; duration: Appearance.anim.fast; easing.type: Easing.OutCubic }
                }

                MaterialIcon {
                    anchors.centerIn: parent
                    icon: card.shown ? card.info.icon : ""
                    fill: 1
                    iconSize: root.cell * 0.5
                    color: card.info.done ? Colors.m3onPrimaryContainer : Colors.m3onSecondaryContainer
                }
                MaterialIcon {
                    anchors.centerIn: parent
                    visible: !card.shown
                    icon: "help"
                    iconSize: root.cell * 0.4
                    color: Qt.alpha(Colors.m3onSurface, 0.3)
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.flip(card.index)
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
                text: `${Translation.tr("All pairs found in %1 moves").arg(root.moves)}\n${Translation.tr("Click to play again")}`
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
        path: `${Paths.state}/memory.txt`
        printErrors: false
        onLoaded: root.best = parseInt(text()) || 0
    }
}
