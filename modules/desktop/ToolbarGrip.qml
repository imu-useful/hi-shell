import QtQuick
import qs.common
import qs.common.widgets

// A resize handle of the desktop edit toolbar: on its right edge (width), bottom edge
// (height) or bottom right corner (both). The card holds the top left corner in place
// while it's dragged and saves the size when it's let go; double click = the default size
// along the grip's directions.
Rectangle {
    id: root

    required property Item card
    property bool horizontal: false
    property bool vertical: false
    readonly property bool corner: horizontal && vertical

    anchors.horizontalCenter: horizontal ? card.right : card.horizontalCenter
    anchors.verticalCenter: vertical ? card.bottom : card.verticalCenter
    implicitWidth: corner ? 24 : horizontal ? 12 : 36
    implicitHeight: corner ? 24 : vertical ? 12 : 36
    radius: Math.min(width, height) / 2
    color: area.pressed ? Colors.m3primary : Colors.m3secondaryContainer
    border.width: 2
    border.color: Colors.m3primary

    MaterialIcon {
        visible: root.corner
        anchors.centerIn: parent
        icon: "open_in_full"
        iconSize: 14
        color: area.pressed ? Colors.m3onPrimary : Colors.m3onSecondaryContainer
    }

    MouseArea {
        id: area
        anchors.fill: parent
        anchors.margins: -6
        cursorShape: root.corner ? Qt.SizeFDiagCursor : root.horizontal ? Qt.SizeHorCursor : Qt.SizeVerCursor
        preventStealing: true
        property point start

        onPressed: mouse => {
            start = mapToItem(root.card.parent, mouse.x, mouse.y);
            root.card.beginResize();
        }
        onPositionChanged: mouse => {
            if (!pressed)
                return;
            const p = mapToItem(root.card.parent, mouse.x, mouse.y);
            root.card.resizeBy(root.horizontal ? p.x - start.x : 0, root.vertical ? p.y - start.y : 0);
        }
        onReleased: root.card.endResize()
        onCanceled: root.card.cancelResize()
        onDoubleClicked: root.card.resetSize(root.horizontal, root.vertical)
    }
}
