import QtQuick
import qs.common
import qs.common.widgets
import qs.services

// The number of open tasks; click opens the Todo tab of the right sidebar. Hidden when there are none.
BarWidget {
    id: root

    shown: Todo.pending > 0
    clickable: true
    padding: 8
    contentWidth: grid.implicitWidth
    contentHeight: grid.implicitHeight
    onClicked: {
        ShellState.sidebarTab = "todo";
        ShellState.sidebarRightOpen = true;
    }

    Grid {
        id: grid
        anchors.centerIn: parent
        columns: root.vertical ? 1 : 2
        spacing: 4
        verticalItemAlignment: Grid.AlignVCenter
        horizontalItemAlignment: Grid.AlignHCenter

        MaterialIcon { icon: "checklist"; iconSize: 17; color: Colors.m3primary }
        StyledText {
            text: Todo.pending
            font.pixelSize: Appearance.font.size.labelMedium + 1
        }
    }
}
