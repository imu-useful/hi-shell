import QtQuick
import Quickshell
import Quickshell.Services.SystemTray
import Quickshell.Widgets
import qs.common
import qs.common.widgets
import qs.services

// System tray icons. Left click = activate (or menu for menu-only items),
// right click = menu, middle click = secondary action.
BarWidget {
    id: root

    readonly property int iconSize: 18

    shown: Tray.items.length > 0
    padding: 8
    contentWidth: grid.implicitWidth
    contentHeight: grid.implicitHeight

    Grid {
        id: grid
        anchors.centerIn: parent
        columns: root.vertical ? 1 : Tray.items.length
        spacing: 10

        Repeater {
            model: Tray.items

            Item {
                id: entry

                required property SystemTrayItem modelData

                width: root.iconSize
                height: root.iconSize

                function openMenu() {
                    const window = QsWindow.window;
                    const pos = entry.mapToItem(window.contentItem, 0, 0);
                    const below = root.popupEdge === Edges.Bottom;
                    modelData.display(window, pos.x, below ? pos.y + entry.height + 10 : pos.y);
                }

                IconImage {
                    anchors.fill: parent
                    source: entry.modelData.icon
                    smooth: true
                }

                HoverHandler {
                    id: hover
                }

                MouseArea {
                    anchors.fill: parent
                    anchors.margins: -4
                    acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
                    cursorShape: Qt.PointingHandCursor
                    onClicked: mouse => {
                        if (mouse.button === Qt.MiddleButton)
                            entry.modelData.secondaryActivate();
                        else if (mouse.button === Qt.RightButton || entry.modelData.onlyMenu)
                            entry.openMenu();
                        else
                            entry.modelData.activate();
                    }
                }

                StyledPopup {
                    target: entry
                    hovered: hover.hovered
                    edge: root.popupEdge
                    openDelay: 500
                    padding: 10

                    StyledText {
                        text: entry.modelData.tooltipTitle || entry.modelData.title || entry.modelData.id
                    }
                }
            }
        }
    }
}
