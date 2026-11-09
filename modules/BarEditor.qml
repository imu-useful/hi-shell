import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import qs.common
import qs.common.widgets
import qs.services
import "settings/BarWidgets.js" as BarWidgets

// The panel that comes with the bar's edit mode (ShellState.barEdit): the widgets that can be added to a bar,
// and Done. The widgets already on a bar are dragged on the bar itself (Bar.qml): to another place, or off it
// to remove them.
Scope {
    id: root

    property string barId: "main"
    property string section: "center"

    readonly property var screenName: Quickshell.screens[0]?.name ?? ""
    readonly property var extraBars: BarLayout.arr(Config.options.bar.extra)
    readonly property var current: BarLayout.spec(screenName, barId)
    // Every widget of the bar, in all three sections.
    readonly property var present: [...current.left, ...current.center, ...current.right]
    readonly property var addable: [...Object.keys(BarWidgets.names), ...Object.keys(Config.options.bar.instances ?? {})]
        .filter(id => id === "divider" || id === "zoneClock" || !present.includes(id))

    function add(id) {
        BarLayout.writeList(screenName, barId, section, [...current[section], id]);
    }

    // A bar that was removed while editing falls back to the main one.
    onExtraBarsChanged: if (barId !== "main" && !extraBars.some(b => b.id === barId)) barId = "main"

    LazyLoader {
        active: ShellState.barEdit

        PanelWindow {
            screen: Quickshell.screens[0] ?? null
            anchors.top: false
            anchors.bottom: false
            exclusiveZone: 0
            implicitWidth: card.width
            implicitHeight: card.height
            color: "transparent"
            WlrLayershell.namespace: "hi-shell-bar-editor"
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand

            Rectangle {
                id: card
                width: 560
                height: col.implicitHeight + 32
                radius: Appearance.shape.panel
                color: Colors.m3surfaceContainerHigh
                border.width: 1
                border.color: Qt.alpha(Colors.m3outlineVariant, 0.6)

                ColumnLayout {
                    id: col
                    anchors.fill: parent
                    anchors.margins: 16
                    spacing: 10

                    RowLayout {
                        Layout.fillWidth: true
                        MaterialIcon {
                            icon: "edit"
                            iconSize: 22
                            color: Colors.m3primary
                        }
                        StyledText {
                            Layout.fillWidth: true
                            text: Translation.tr("Edit the bar")
                            font.pixelSize: Appearance.font.size.titleMedium
                            font.weight: Font.Medium
                        }
                        M3Button {
                            icon: "check"
                            text: Translation.tr("Done")
                            onClicked: ShellState.barEdit = false
                        }
                    }
                    StyledText {
                        Layout.fillWidth: true
                        wrapMode: Text.WordWrap
                        text: Translation.tr("Drag a widget on the bar to move it, or off the bar to remove it. Pick a widget below to add it.")
                        font.pixelSize: Appearance.font.size.labelMedium
                        color: Colors.m3onSurfaceVariant
                    }

                    Flow {
                        Layout.fillWidth: true
                        spacing: 6
                        visible: root.extraBars.length > 0

                        Chip {
                            icon: "toolbar"
                            text: Translation.tr("Main bar")
                            selected: root.barId === "main"
                            onClicked: root.barId = "main"
                        }
                        Repeater {
                            model: root.extraBars

                            Chip {
                                required property var modelData
                                icon: "dock_to_bottom"
                                text: modelData.id
                                selected: root.barId === modelData.id
                                onClicked: root.barId = modelData.id
                            }
                        }
                    }

                    SegmentedButton {
                        Layout.fillWidth: true
                        model: [{ text: Translation.tr("Left") }, { text: Translation.tr("Center") }, { text: Translation.tr("Right") }]
                        currentIndex: ["left", "center", "right"].indexOf(root.section)
                        onSelected: index => root.section = ["left", "center", "right"][index]
                    }

                    Flow {
                        Layout.fillWidth: true
                        spacing: 6

                        Repeater {
                            model: root.addable

                            Chip {
                                required property string modelData
                                icon: BarWidgets.icons[modelData.split("#")[0]] ?? "widgets"
                                text: BarWidgets.names[modelData] ? Translation.tr(BarWidgets.names[modelData]) : modelData
                                onClicked: root.add(modelData)
                            }
                        }
                    }
                }
            }
        }
    }
}
