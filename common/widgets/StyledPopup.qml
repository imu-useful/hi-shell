import QtQuick
import QtQuick.Effects
import Quickshell
import qs.common

// Popup card anchored to a bar widget (resources, weather, battery, ...).
// Opens shortly after the target is hovered, stays open while the pointer is
// over the popup, and closes shortly after it leaves both. Usage:
//
//   Item { id: w; HoverHandler { id: hover }
//          StyledPopup { target: w; hovered: hover.hovered; StyledText { text: "..." } } }
PopupWindow {
    id: root

    required property Item target
    property bool hovered: false
    // Keep open regardless of hover (e.g. toggled by a click).
    property bool pinned: false
    // Side of the target the popup opens on: Edges.Bottom / Top / Left / Right.
    property int edge: Edges.Bottom
    property int gap: 6
    property int padding: 16
    property int openDelay: 200
    property int closeDelay: 250
    default property alias content: contentArea.data

    readonly property int shadowPad: 14
    readonly property bool wanted: pinned || hovered || popupHover.hovered
    property bool shown: false

    readonly property bool vertical: edge === Edges.Top || edge === Edges.Bottom
    readonly property int offset: gap - shadowPad

    onWantedChanged: {
        if (wanted) {
            closeTimer.stop();
            if (!shown)
                openTimer.restart();
        } else {
            openTimer.stop();
            closeTimer.restart();
        }
    }

    Component.onCompleted: {
        if (wanted)
            openTimer.restart();
    }

    Timer {
        id: openTimer
        interval: root.pinned ? 0 : root.openDelay
        onTriggered: root.shown = true
    }
    Timer {
        id: closeTimer
        interval: root.closeDelay
        onTriggered: root.shown = false
    }

    anchor.item: target
    anchor.rect: edge === Edges.Bottom ? Qt.rect(0, 0, target.width, target.height + offset)
               : edge === Edges.Top ? Qt.rect(0, -offset, target.width, target.height + offset)
               : edge === Edges.Right ? Qt.rect(0, 0, target.width + offset, target.height)
               : Qt.rect(-offset, 0, target.width + offset, target.height)
    anchor.edges: edge
    anchor.gravity: edge

    visible: shown || card.opacity > 0
    implicitWidth: card.implicitWidth + shadowPad * 2
    implicitHeight: card.implicitHeight + shadowPad * 2
    color: "transparent"

    Item {
        anchors.fill: parent

        HoverHandler {
            id: popupHover
        }

        Rectangle {
            id: card

            property real slide: root.shown ? 0 : 8

            x: root.shadowPad + (root.vertical ? 0 : root.edge === Edges.Right ? -slide : slide)
            y: root.shadowPad + (!root.vertical ? 0 : root.edge === Edges.Bottom ? -slide : slide)
            implicitWidth: contentArea.childrenRect.width + root.padding * 2
            implicitHeight: contentArea.childrenRect.height + root.padding * 2
            width: implicitWidth
            height: implicitHeight
            radius: Appearance.rounding.large
            color: Colors.m3surfaceContainer
            border.width: 1
            border.color: Qt.alpha(Colors.m3outlineVariant, 0.6)

            opacity: root.shown ? 1 : 0
            scale: root.shown ? 1 : 0.96
            Behavior on opacity { EffectAnim { duration: Appearance.anim.fast } }
            Behavior on scale { EffectAnim {} }
            Behavior on slide { EffectAnim {} }

            layer.enabled: true
            layer.effect: MultiEffect {
                shadowEnabled: true
                shadowColor: Qt.alpha("black", 0.45)
                shadowBlur: 0.6
                shadowVerticalOffset: 2
            }

            Item {
                id: contentArea
                x: root.padding
                y: root.padding
            }
        }
    }
}
