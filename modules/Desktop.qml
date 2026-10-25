import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs.common
import qs.common.widgets
import qs.services
import qs.modules.desktop
import "desktop/Layout.js" as DesktopLayout

// Desktop layer, one per screen: wallpaper, widgets (Config desktop.*) and a
// full-width visualizer. Right-click the empty desktop (or
// `qs -c hi-shell ipc call desktop edit`) to drag widgets and turn them on / off.
Scope {
    id: root

    readonly property var options: Config.options.desktop
    readonly property bool editing: ShellState.desktopEditing

    function setEditing(value) {
        ShellState.desktopEditing = value;
    }

    function setEnabled(id, enabled) {
        const layout = Object.assign({}, options.layout);
        layout[id] = Object.assign({}, DesktopLayout.entry(options.layout, id), { enabled });
        options.layout = layout;
    }

    IpcHandler {
        target: "desktop"

        function edit(): void {
            root.setEditing(true);
        }
        function done(): void {
            root.setEditing(false);
        }
        function toggleEdit(): void {
            root.setEditing(!root.editing);
        }
        function resetLayout(): void {
            root.options.layout = {};
        }
    }

    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: window

            required property ShellScreen modelData
            readonly property bool hasWidgets: root.options.widgets && (root.options.monitor ? modelData.name === root.options.monitor : modelData === Quickshell.screens[0])

            screen: modelData
            anchors.top: true
            anchors.bottom: true
            anchors.left: true
            anchors.right: true
            exclusionMode: ExclusionMode.Ignore
            color: Colors.m3surface

            WlrLayershell.namespace: "hi-shell-desktop"
            // Above windows while editing so widgets can be dragged.
            WlrLayershell.layer: root.editing && hasWidgets ? WlrLayer.Overlay : WlrLayer.Background
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand

            // --- Wallpaper, cross-faded on change ---
            Item {
                anchors.fill: parent
                visible: root.options.wallpaper

                property string source: Colors.wallpaper ? `file://${Colors.wallpaper}` : ""
                property bool flip: false
                onSourceChanged: {
                    flip = !flip;
                    (flip ? b : a).source = source;
                }

                Image {
                    id: a
                    anchors.fill: parent
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    sourceSize: Qt.size(window.width, window.height)
                    opacity: !parent.flip && status === Image.Ready ? 1 : 0
                    Behavior on opacity { EffectAnim { duration: Appearance.anim.slow * 2 } }
                }
                Image {
                    id: b
                    anchors.fill: parent
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    sourceSize: Qt.size(window.width, window.height)
                    opacity: parent.flip && status === Image.Ready ? 1 : 0
                    Behavior on opacity { EffectAnim { duration: Appearance.anim.slow * 2 } }
                }
            }

            // Dim the wallpaper a little while editing.
            Rectangle {
                anchors.fill: parent
                color: "black"
                opacity: root.editing && window.hasWidgets ? 0.35 : 0
                Behavior on opacity { EffectAnim {} }
            }

            // Right-click the empty desktop to edit widgets; any click there ends editing.
            MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.LeftButton | Qt.RightButton
                onClicked: mouse => {
                    if (mouse.button === Qt.RightButton && window.hasWidgets)
                        root.setEditing(!root.editing);
                    else if (root.editing)
                        root.setEditing(false);
                }
            }

            Shortcut {
                sequence: "Escape"
                enabled: root.editing
                onActivated: root.setEditing(false)
            }

            // --- Visualizer along the bottom ---
            Item {
                id: visualizer
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                height: 180
                visible: root.options.visualizer && window.hasWidgets && Mpris.playing

                readonly property int bars: 64
                property list<real> levels: []

                Process {
                    running: visualizer.visible && Appearance.anim.speed > 0
                    command: ["sh", "-c", 'cfg=$(mktemp); printf "%b" "$1" > "$cfg"; exec cava -p "$cfg"', "sh",
                        `[general]\nbars = ${visualizer.bars}\nframerate = 30\n[input]\nmethod = pipewire\n[output]\nmethod = raw\nraw_target = /dev/stdout\ndata_format = ascii\nascii_max_range = 100\nbar_delimiter = 59\n[smoothing]\nmonstercat = 1\n`]
                    stdout: SplitParser {
                        onRead: line => visualizer.levels = line.split(";").filter(v => v !== "").map(v => Number(v) / 100)
                    }
                    onRunningChanged: if (!running) visualizer.levels = []
                }

                Row {
                    anchors.bottom: parent.bottom
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: 4

                    Repeater {
                        model: visualizer.bars

                        Rectangle {
                            required property int index
                            readonly property real level: visualizer.levels[index] ?? 0
                            anchors.bottom: parent.bottom
                            width: (visualizer.width - (visualizer.bars - 1) * 4) / visualizer.bars
                            height: Math.max(4, level * visualizer.height)
                            radius: width / 2
                            color: Qt.alpha(Colors.m3primary, 0.55)
                            Behavior on height { NumberAnimation { duration: 60 } }
                        }
                    }
                }
            }

            // --- Widgets ---
            Item {
                id: widgets
                anchors.fill: parent
                visible: window.hasWidgets

                DesktopWidget {
                    widgetId: "shapeClock"
                    editing: root.editing
                    ShapeClock {}
                }
                DesktopWidget {
                    widgetId: "digitalClock"
                    editing: root.editing
                    DigitalClock {}
                }
                DesktopWidget {
                    widgetId: "greeting"
                    editing: root.editing
                    GreetingCard {}
                }
                DesktopWidget {
                    widgetId: "media"
                    editing: root.editing
                    MediaCard {}
                }
                DesktopWidget {
                    widgetId: "weather"
                    editing: root.editing
                    WeatherCard {}
                }
                DesktopWidget {
                    widgetId: "resources"
                    editing: root.editing
                    ResourceTiles {}
                }
                DesktopWidget {
                    widgetId: "calendar"
                    editing: root.editing
                    CalendarCard {}
                }
                DesktopWidget {
                    widgetId: "todo"
                    editing: root.editing
                    TodoCard {}
                }
                DesktopWidget {
                    widgetId: "worldClock"
                    editing: root.editing
                    WorldClockCard {}
                }
                DesktopWidget {
                    widgetId: "notes"
                    editing: root.editing
                    NotesCard {}
                }
                DesktopWidget {
                    widgetId: "timers"
                    editing: root.editing
                    TimersCard {}
                }
                DesktopWidget {
                    widgetId: "userCard"
                    editing: root.editing
                    UserCard {}
                }
                DesktopWidget {
                    widgetId: "imageFrame"
                    editing: root.editing
                    ImageFrame {}
                }
            }

            // --- Edit toolbar ---
            DesktopCard {
                visible: root.editing && window.hasWidgets
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.bottom: parent.bottom
                anchors.bottomMargin: 48
                width: Math.min(parent.width - 64, toolbar.implicitWidth + 32)
                height: toolbar.implicitHeight + 24
                baseColor: Colors.m3surfaceContainerHigh

                ColumnLayout {
                    id: toolbar
                    anchors.centerIn: parent
                    width: parent.width - 32
                    spacing: 10

                    RowLayout {
                        Layout.fillWidth: true
                        MaterialIcon {
                            icon: "dashboard_customize"
                            color: Colors.m3primary
                        }
                        StyledText {
                            Layout.fillWidth: true
                            text: "Drag widgets to move them · tap a chip to show or hide"
                        }
                        M3Button {
                            tonal: true
                            text: "Reset"
                            onClicked: root.options.layout = {}
                        }
                        M3Button {
                            text: "Done"
                            icon: "check"
                            onClicked: root.setEditing(false)
                        }
                    }

                    Flow {
                        Layout.fillWidth: true
                        spacing: 6
                        Repeater {
                            model: DesktopLayout.ids
                            Chip {
                                required property string modelData
                                text: DesktopLayout.names[modelData]
                                selected: DesktopLayout.entry(root.options.layout, modelData).enabled
                                onClicked: root.setEnabled(modelData, !selected)
                            }
                        }
                    }
                }
            }
        }
    }
}
