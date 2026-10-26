import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland
import qs.common
import qs.common.widgets
import qs.common.shapes
import qs.services
import qs.modules.desktop
import "desktop/Layout.js" as DesktopLayout

// Desktop layer, one per screen: wallpaper, widgets (Config desktop.*) and a
// full-width visualizer. Right-click the empty desktop (or
// `qs -c hi-shell ipc call desktop edit`) to drag widgets and turn them on / off.
Scope {
    id: root

    readonly property var options: Config.options.desktop
    readonly property string frame: Config.options.wallpapers.frame
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
            readonly property bool hasWidgets: root.options.widgets && (root.options.monitor ? modelData?.name === root.options.monitor : modelData === Quickshell.screens[0])
            readonly property HyprlandMonitor monitor: Hyprland.monitorFor(modelData)
            readonly property bool covered: !root.editing && Hyprland.toplevels.values.some(t => t.workspace?.id === monitor?.activeWorkspace?.id)
            // 1 on the empty desktop, 0 with windows open (in focus mode): blur, frame and
            // widgets fade with it, so the wallpaper behind windows is sharp and uncluttered.
            property real reveal: covered && root.options.focusMode ? 0 : 1

            // Startup: begins when the wallpaper is ready to show (a frame later).
            Timer {
                id: introStart
                interval: 80
                onTriggered: ShellState.started = true
            }

            // Startup: the wallpaper fades in, then the frame pops in.
            property real intro: ShellState.started ? 1 : 0
            Behavior on intro {
                NumberAnimation { duration: Appearance.anim.slow * 1.75; easing.type: Easing.OutCubic }
            }
            property real frameIntro: ShellState.started ? 1 : 0
            Behavior on frameIntro {
                SequentialAnimation {
                    PauseAnimation { duration: 200 }
                    SpringAnim { duration: Appearance.anim.spatial * 1.4 }
                }
            }
            Behavior on reveal {
                NumberAnimation { duration: Appearance.anim.slow * 1.5; easing.type: Easing.InOutCubic }
            }

            Binding {
                when: window.hasWidgets
                target: ShellState
                property: "desktopCovered"
                value: window.covered
            }

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
                id: wallpaper
                anchors.fill: parent
                visible: root.options.wallpaper
                opacity: window.intro
                // With a frame shape the full-screen copy is blurred and dimmed behind it,
                // on the empty desktop only; sharp again behind windows.
                // A cover is small, so it stays blurred behind windows too.
                readonly property real blurAmount: CoverMode.active ? 1 : window.reveal
                layer.enabled: (root.frame !== "" || CoverMode.active) && blurAmount > 0
                layer.effect: MultiEffect {
                    blurEnabled: true
                    blur: wallpaper.blurAmount
                    blurMax: 64
                    brightness: -0.25 * wallpaper.blurAmount
                    saturation: -0.2 * wallpaper.blurAmount
                }

                // The wallpaper, or the playing track's cover in cover mode.
                // (The cover from the local copy CoverMode downloads: quicker than fetching the
                // player's URL again, and the same picture the palette came from.)
                property string source: CoverMode.active ? (CoverMode.file ? `file://${CoverMode.file}` : Mpris.artUrl)
                                                         : Wallpapers.current ? `file://${Wallpapers.current}` : ""
                property bool flip: false
                onSourceChanged: {
                    flip = !flip;
                    (flip ? b : a).source = source;
                }

                Image {
                    id: a
                    anchors.fill: parent
                    onStatusChanged: if (status === Image.Ready && !ShellState.started) introStart.restart()
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    sourceSize: Qt.size(window.width, window.height)
                    opacity: !parent.flip && status === Image.Ready ? 1 : 0
                    Behavior on opacity { EffectAnim { duration: Appearance.anim.slow * 2 } }
                }
                Image {
                    id: b
                    anchors.fill: parent
                    onStatusChanged: if (status === Image.Ready && !ShellState.started) introStart.restart()
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    sourceSize: Qt.size(window.width, window.height)
                    opacity: parent.flip && status === Image.Ready ? 1 : 0
                    Behavior on opacity { EffectAnim { duration: Appearance.anim.slow * 2 } }
                }
            }

            // Shaped frame: the sharp wallpaper inside a big Material shape. While music
            // plays (and the desktop is in view) the shape turns and pulses to the bass.
            Item {
                id: frame
                // In cover mode the cover always gets a frame (a square one without a chosen shape).
                readonly property string shape: root.frame || (CoverMode.active ? "square" : "")
                visible: root.options.wallpaper && shape !== "" && window.reveal > 0
                opacity: window.reveal * Math.min(1, window.frameIntro)
                anchors.centerIn: parent
                width: Math.min(parent.width, parent.height) * 0.62
                height: width

                readonly property bool dancing: visible && Config.options.wallpapers.frameDance && Mpris.playing
                    && !window.covered && Appearance.anim.speed > 0
                property real spin: 0

                // Count in with the Beat service while dancing.
                property bool counted: false
                onDancingChanged: {
                    if (dancing !== counted) {
                        Beat.users += dancing ? 1 : -1;
                        counted = dancing;
                    }
                }
                Component.onCompleted: if (dancing) { Beat.users++; counted = true; }
                Component.onDestruction: if (counted) Beat.users--

                Connections {
                    target: Beat
                    enabled: frame.dancing
                    // A slow turn that speeds up on bass hits.
                    function onFrame(dt) {
                        frame.spin = (frame.spin + dt * (8 + 70 * Beat.bass)) % 360;
                    }
                }

                // Swell with the bass; ease back when the music stops. Grows in as it appears.
                scale: (0.6 + 0.4 * window.frameIntro) * (0.9 + 0.1 * window.reveal) * (dancing ? 1 + 0.07 * Beat.bass : 1)
                Behavior on scale {
                    enabled: !frame.dancing
                    SpatialAnim { duration: Appearance.anim.spatial }
                }

                MaterialShape {
                    anchors.fill: parent
                    anchors.margins: -6
                    rotation: frame.spin
                    shape: frame.shape || "circle"
                    color: Qt.alpha(Colors.m3primary, 0.5 + 0.3 * (frame.dancing ? Beat.bass : 0))
                }
                ShapeImage {
                    anchors.fill: parent
                    shape: frame.shape || "circle"
                    maskRotation: frame.spin
                    source: wallpaper.source
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

            // --- Widgets ---
            Item {
                id: widgets
                anchors.fill: parent
                visible: window.hasWidgets
                // Hidden (not unloaded) behind windows, so widgets keep their state.
                opacity: window.reveal
                scale: 0.97 + 0.03 * window.reveal

                // Alignment guides while a widget is dragged (-1 = none); set by DesktopWidget.
                property real guideX: -1
                property real guideY: -1

                Rectangle {
                    visible: widgets.guideX >= 0
                    x: Math.round(widgets.guideX) - 1
                    width: 2
                    height: parent.height
                    color: Colors.m3tertiary
                    z: 10
                }
                Rectangle {
                    visible: widgets.guideY >= 0
                    y: Math.round(widgets.guideY) - 1
                    height: 2
                    width: parent.width
                    color: Colors.m3tertiary
                    z: 10
                }

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
                            text: Translation.tr("Drag widgets to move them · tap a chip to show or hide")
                        }
                        M3Button {
                            tonal: true
                            text: Translation.tr("Reset")
                            onClicked: root.options.layout = {}
                        }
                        M3Button {
                            text: Translation.tr("Done")
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
                                text: Translation.tr(DesktopLayout.names[modelData])
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
