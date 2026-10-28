import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Hyprland
import Quickshell.Widgets
import qs.common
import qs.services

// A Material You menu for the entries an app exposes (the system tray's menus): a rounded
// tonal card with a hover / press state layer on every row, check marks and radio dots,
// and submenus that replace the list (with a back row) instead of opening a second window.
// Usage:
//
//   PanelLoader { id: lazy; ContextMenu { target: icon; handle: item.menu; shown: lazy.revealed
//                                          onCloseRequested: lazy.shown = false } }   ... lazy.shown = true
//
// Wrapped in a PanelLoader the window (and its shadow layer) exists only while the menu is open.
PopupWindow {
    id: root

    required property Item target
    // A QsMenuHandle: a tray item's `menu`.
    property var handle: null
    // Side of the target the menu opens on: Edges.Bottom / Top.
    property int edge: Edges.Bottom
    property int gap: 8

    readonly property int shadowPad: 14
    readonly property int menuWidth: 248
    // The submenus entered so far: [{ handle, title }].
    property var trail: []
    readonly property var current: trail.length > 0 ? trail[trail.length - 1].handle : handle
    // Set by the owner (a PanelLoader's `revealed`); the menu asks to be closed through the signal.
    property bool shown: false
    // No pop-in, spring or shadow in game mode and power saving: the menu just appears.
    readonly property bool animated: !Toggles.gameMode && !PowerSaver.enabled && Appearance.anim.speed > 0

    signal closeRequested

    function close() {
        closeRequested();
    }

    anchor.item: target
    anchor.rect: edge === Edges.Bottom ? Qt.rect(0, 0, target.width, target.height + gap - shadowPad)
               : Qt.rect(0, -(gap - shadowPad), target.width, target.height + gap - shadowPad)
    anchor.edges: edge
    anchor.gravity: edge
    anchor.adjustment: PopupAdjustment.Slide | PopupAdjustment.Flip

    visible: shown || card.opacity > 0
    implicitWidth: menuWidth + shadowPad * 2
    implicitHeight: card.height + shadowPad * 2
    color: "transparent"

    onShownChanged: if (!shown) trail = []

    HyprlandFocusGrab {
        windows: [root]
        active: root.shown
        onCleared: root.close()
    }

    Shortcut {
        sequence: "Escape"
        enabled: root.shown
        onActivated: root.trail.length > 0 ? root.trail = root.trail.slice(0, -1) : root.close()
    }

    QsMenuOpener {
        id: opener
        menu: root.shown ? root.current : null
    }

    Rectangle {
        id: card

        property real slide: root.shown ? 0 : 8

        x: root.shadowPad
        y: root.shadowPad + (root.edge === Edges.Bottom ? -slide : slide)
        width: root.menuWidth
        height: column.implicitHeight + 16
        radius: Appearance.rounding.large
        color: Colors.m3surfaceContainer
        border.width: 1
        border.color: Qt.alpha(Colors.m3outlineVariant, 0.6)

        opacity: root.shown ? 1 : 0
        scale: root.shown ? 1 : 0.9
        transformOrigin: root.edge === Edges.Bottom ? Item.Top : Item.Bottom
        Behavior on opacity { enabled: root.animated; EffectAnim { duration: Appearance.anim.fast } }
        Behavior on scale { enabled: root.animated; SpringAnim {} }
        Behavior on slide { enabled: root.animated; SpringAnim {} }
        Behavior on height { enabled: root.animated; SpringAnim {} }

        layer.enabled: root.animated
        layer.effect: MultiEffect {
            shadowEnabled: true
            shadowColor: Qt.alpha("black", 0.45)
            shadowBlur: 0.6
            shadowVerticalOffset: 2
        }

        component MenuRow: Rectangle {
            id: row

            property string label: ""
            property string iconName: ""
            // "none" | "check" | "radio"
            property string mark: "none"
            property bool marked: false
            property bool submenu: false
            property bool back: false

            signal activated

            width: parent?.width ?? 0
            height: 40
            radius: Appearance.rounding.medium
            color: "transparent"
            opacity: enabled ? 1 : 0.38

            Item {
                id: lead
                x: 12
                anchors.verticalCenter: parent.verticalCenter
                width: 20
                height: 20

                MaterialIcon {
                    anchors.centerIn: parent
                    visible: row.back || (row.mark !== "none" && row.marked) || (row.mark === "radio")
                    icon: row.back ? "arrow_back" : row.mark === "radio" ? (row.marked ? "radio_button_checked" : "radio_button_unchecked") : "check"
                    iconSize: 20
                    color: row.marked ? Colors.m3primary : Colors.m3onSurfaceVariant
                }
                IconImage {
                    anchors.fill: parent
                    visible: !row.back && row.mark === "none" && row.iconName !== ""
                    source: row.iconName
                    smooth: true
                }
            }

            StyledText {
                anchors.left: parent.left
                anchors.leftMargin: 44
                anchors.right: parent.right
                anchors.rightMargin: row.submenu ? 40 : 14
                anchors.verticalCenter: parent.verticalCenter
                text: row.label
                elide: Text.ElideRight
                color: row.back ? Colors.m3onSurfaceVariant : Colors.m3onSurface
                font.weight: row.back ? Font.Medium : Font.Normal
            }

            MaterialIcon {
                visible: row.submenu
                anchors.right: parent.right
                anchors.rightMargin: 12
                anchors.verticalCenter: parent.verticalCenter
                icon: "chevron_right"
                iconSize: 20
                color: Colors.m3onSurfaceVariant
            }

            StateLayer {
                enabled: row.enabled
                onClicked: row.activated()
            }
        }

        Column {
            id: column
            x: 8
            y: 8
            width: parent.width - 16
            spacing: 0

            MenuRow {
                visible: root.trail.length > 0
                height: visible ? 40 : 0
                back: true
                label: root.trail.length > 0 ? root.trail[root.trail.length - 1].title : ""
                onActivated: root.trail = root.trail.slice(0, -1)
            }

            Repeater {
                model: opener.children

                Loader {
                    id: slot

                    required property var modelData

                    width: column.width
                    sourceComponent: modelData.isSeparator ? separator : entry

                    Component {
                        id: separator
                        Item {
                            width: slot.width
                            height: 17
                            Rectangle {
                                anchors.centerIn: parent
                                width: parent.width - 24
                                height: 1
                                color: Colors.m3outlineVariant
                            }
                        }
                    }

                    Component {
                        id: entry
                        MenuRow {
                            width: slot.width
                            enabled: slot.modelData.enabled
                            label: (slot.modelData.text ?? "").replace(/&(?!&)/g, "").replace(/&&/g, "&")
                            iconName: slot.modelData.icon ?? ""
                            mark: slot.modelData.buttonType === QsMenuButtonType.CheckBox ? "check"
                                : slot.modelData.buttonType === QsMenuButtonType.RadioButton ? "radio" : "none"
                            marked: slot.modelData.checkState === Qt.Checked
                            submenu: slot.modelData.hasChildren
                            onActivated: {
                                if (slot.modelData.hasChildren) {
                                    root.trail = [...root.trail, { handle: slot.modelData, title: label }];
                                } else {
                                    slot.modelData.triggered();
                                    root.close();
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
