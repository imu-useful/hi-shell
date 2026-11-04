import QtQuick
import qs.common
import qs.common.widgets
import qs.services

// What comes out under the island for its notification: the message in a second island and, under
// it, the buttons. `showMessage` pulls the message in and out (on hover); the buttons follow
// `showButtons`, and slide up into the gap the message leaves.
Item {
    id: root

    property bool showMessage: false
    property bool showButtons: false
    property bool floating: false
    // Wait before the buttons pop (for the island to land first).
    property int delay: 0

    readonly property bool hasButtons: Island.buttons.length > 0

    implicitWidth: Math.max(message.implicitWidth, actions.implicitWidth)
    implicitHeight: actions.y + (hasButtons ? actions.implicitHeight : 0)

    IslandMessage {
        id: message
        anchors.horizontalCenter: parent.horizontalCenter
        shown: root.showMessage
        visible: pop > 0.01
    }

    IslandActions {
        id: actions
        anchors.horizontalCenter: parent.horizontalCenter
        y: root.showMessage ? message.implicitHeight + 8 : 0
        Behavior on y { SpringAnim { overshoot: 1.4; duration: Appearance.anim.spatial } }
        shown: root.showButtons
        floating: root.floating
        delay: root.delay
    }
}
