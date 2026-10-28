import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import qs.common
import qs.common.widgets
import qs.services
import qs.modules.notifications

// Notification popups in the corner next to the bar, on the focused monitor.
// The window only takes input where cards are; the rest is click-through. It takes keyboard
// focus on a click while a card has an inline reply field (messengers), so you can type in it.
PanelWindow {
    id: root

    readonly property bool atBottom: Config.options.bar.position === "bottom"
    readonly property int maxShown: 5

    screen: Quickshell.screens.find(s => s.name === Hyprland.focusedMonitor?.name) ?? Quickshell.screens[0]
    visible: Notifications.popups.length > 0

    anchors.top: !atBottom
    anchors.bottom: atBottom
    anchors.right: true
    margins.top: Appearance.sizes.barMargin
    margins.bottom: Appearance.sizes.barMargin
    margins.right: Appearance.sizes.barMargin
    exclusiveZone: 0
    implicitWidth: 380 + 16
    implicitHeight: Math.max(1, column.height + 16)
    mask: Region { item: column }
    color: "transparent"

    WlrLayershell.namespace: "hi-shell-notifications"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: Notifications.popups.some(n => n.notification?.hasInlineReply) ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None

    Column {
        id: column

        x: 8
        y: root.atBottom ? root.height - height - 8 : 8
        width: 380
        spacing: 8

        move: Transition { SpatialAnim { properties: "y"; duration: Appearance.anim.normal } }

        Repeater {
            // ScriptModel diffs by object, so existing cards survive list changes.
            // Newest on top (bottom bar: newest nearest the bar).
            model: ScriptModel {
                values: root.atBottom ? Notifications.popups.slice(0, root.maxShown).reverse() : Notifications.popups.slice(0, root.maxShown)
            }

            NotificationCard {
                id: card

                required property var modelData
                notif: modelData
                popup: true
                width: column.width

                // Slide in from the right.
                property real enter: 0
                transform: Translate { x: (1 - card.enter) * 60 }
                opacity: card.enter
                Component.onCompleted: enter = 1
                Behavior on enter { SpringAnim { overshoot: 1.4 } }
            }
        }
    }
}
