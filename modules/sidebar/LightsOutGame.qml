import QtQuick
import Quickshell
import Quickshell.Io
import qs.common
import qs.common.widgets

// Lights out, for the empty notification center: a click flips the cell and its four neighbours;
// switch every light off. The icon in the corner deals a new board. The fewest moves are kept in
// ~/.local/state/hi-shell/lightsout.txt.
Item {
    id: root

    readonly property int size: 5
    readonly property int gap: 6
    readonly property int headerHeight: 34
    readonly property real boardSize: Math.min(width - 16, 300)
    readonly property real cell: (boardSize - gap * (size - 1)) / size

    implicitHeight: headerHeight + boardSize + 12

    // size * size booleans, true = lit
    property var lights: []
    property int moves: 0
    property int best: 0
    readonly property bool won: lights.length > 0 && !lights.some(l => l)

    function toggle(arr, x, y) {
        if (x >= 0 && y >= 0 && x < size && y < size)
            arr[y * size + x] = !arr[y * size + x];
    }

    function press(i) {
        if (won)
            return;
        apply(i);
        moves++;
        if (won && (best === 0 || moves < best)) {
            best = moves;
            bestFile.setText(String(best) + "\n");
        }
    }

    function apply(i) {
        const next = lights.slice();
        const x = i % size, y = Math.floor(i / size);
        toggle(next, x, y);
        toggle(next, x - 1, y);
        toggle(next, x + 1, y);
        toggle(next, x, y - 1);
        toggle(next, x, y + 1);
        lights = next;
    }

    // Random presses from a dark board: always solvable.
    function newGame() {
        lights = Array(size * size).fill(false);
        do {
            for (let k = 0; k < 10; k++)
                apply(Math.floor(Math.random() * size * size));
        } while (won);
        moves = 0;
    }

    Component.onCompleted: newGame()

    StyledText {
        x: 8
        y: 4
        text: Translation.tr("Lights out")
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
            model: root.size * root.size

            Rectangle {
                id: light

                required property int index
                readonly property bool lit: root.lights[index] ?? false

                x: (index % root.size) * (root.cell + root.gap)
                y: Math.floor(index / root.size) * (root.cell + root.gap)
                width: root.cell
                height: root.cell
                radius: 10
                color: lit ? Colors.m3primary : Colors.m3surfaceContainerHigh
                Behavior on color { ColorAnim {} }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.press(light.index)
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
                text: `${Translation.tr("All lights out in %1 moves").arg(root.moves)}\n${Translation.tr("Click to play again")}`
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
        path: `${Paths.state}/lightsout.txt`
        printErrors: false
        onLoaded: root.best = parseInt(text()) || 0
    }
}
