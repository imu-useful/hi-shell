import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import Quickshell.Services.Pipewire
import qs.common
import qs.common.widgets
import qs.services

// Indicator pill for volume, mic mute, brightness and keyboard layout changes,
// next to the bar on the focused monitor. Click-through; hides after a moment.
Scope {
    id: root

    readonly property PwNode sink: Pipewire.defaultAudioSink
    readonly property PwNode source: Pipewire.defaultAudioSource

    property string icon: ""
    property string label: ""
    property real value: -1 // 0..1, or -1 for no bar
    property bool shown: false
    // Values are reported once at startup and when the default device changes; don't show those.
    property bool armed: false

    function show(icon, label, value) {
        if (!armed)
            return;
        root.icon = icon;
        root.label = label;
        root.value = value;
        shown = true;
        hideTimer.restart();
    }

    function showVolume() {
        const a = sink?.audio;
        if (!a)
            return;
        const icon = a.muted ? "volume_off" : a.volume < 0.01 ? "volume_mute" : a.volume < 0.5 ? "volume_down" : "volume_up";
        show(icon, a.muted ? "Muted" : `${Math.round(a.volume * 100)}%`, a.muted ? 0 : Math.min(1, a.volume));
    }

    function rearm() {
        armed = false;
        armTimer.restart();
    }

    onSinkChanged: rearm()
    onSourceChanged: rearm()
    Component.onCompleted: rearm()

    Timer {
        id: armTimer
        interval: 1500
        onTriggered: root.armed = true
    }

    Timer {
        id: hideTimer
        interval: 1500
        onTriggered: root.shown = false
    }

    PwObjectTracker {
        objects: [root.sink, root.source]
    }

    Connections {
        target: root.sink?.audio ?? null
        function onVolumeChanged() { root.showVolume(); }
        function onMutedChanged() { root.showVolume(); }
    }

    Connections {
        target: root.source?.audio ?? null
        function onMutedChanged() {
            const muted = root.source.audio.muted;
            root.show(muted ? "mic_off" : "mic", muted ? "Microphone muted" : "Microphone on", -1);
        }
    }

    Connections {
        target: Brightness.focused
        function onBrightnessChanged() {
            const b = Brightness.focused.brightness;
            root.show(b < 0.4 ? "brightness_low" : b < 0.75 ? "brightness_medium" : "brightness_high", `${Math.round(b * 100)}%`, b);
        }
    }

    Connections {
        target: HyprlandXkb
        function onLayoutChanged() { root.show("keyboard", HyprlandXkb.layout, -1); }
    }

    PanelLoader {
        id: loader
        shown: root.shown

        PanelWindow {
            id: window

            readonly property bool atBottom: Config.options.bar.position === "bottom"

            screen: Quickshell.screens.find(s => s.name === Hyprland.focusedMonitor?.name) ?? Quickshell.screens[0]
            anchors.top: !atBottom
            anchors.bottom: atBottom
            margins.top: Appearance.sizes.barMargin + 8
            margins.bottom: Appearance.sizes.barMargin + 8
            exclusiveZone: 0
            implicitWidth: pill.width + 32
            implicitHeight: pill.height + 32
            mask: Region {}
            color: "transparent"

            WlrLayershell.namespace: "hi-shell-osd"
            WlrLayershell.layer: WlrLayer.Overlay

            Rectangle {
                id: pill

                anchors.centerIn: parent
                width: 300
                height: 56
                radius: height / 2
                color: Appearance.translucent(Colors.m3surfaceContainer, 0.05)
                border.width: 1
                border.color: Qt.alpha(Colors.m3outlineVariant, 0.6)

                opacity: loader.revealed ? 1 : 0
                scale: loader.revealed ? 1 : 0.9
                Behavior on opacity { EffectAnim {} }
                Behavior on scale { EffectAnim {} }

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 10
                    anchors.rightMargin: 20
                    spacing: 14

                    Rectangle {
                        implicitWidth: 38
                        implicitHeight: 38
                        radius: 19
                        color: Colors.m3primaryContainer

                        MaterialIcon {
                            anchors.centerIn: parent
                            icon: root.icon
                            fill: 1
                            iconSize: 22
                            color: Colors.m3onPrimaryContainer
                        }
                    }

                    // Level bar
                    Rectangle {
                        visible: root.value >= 0
                        Layout.fillWidth: true
                        implicitHeight: 8
                        radius: 4
                        color: Colors.m3secondaryContainer

                        Rectangle {
                            width: parent.width * Math.max(0, root.value)
                            height: parent.height
                            radius: 4
                            color: Colors.m3primary
                            Behavior on width { EffectAnim { duration: Appearance.anim.fast } }
                        }
                    }

                    StyledText {
                        Layout.fillWidth: root.value < 0
                        Layout.minimumWidth: root.value >= 0 ? 44 : 0
                        horizontalAlignment: root.value >= 0 ? Text.AlignRight : Text.AlignLeft
                        text: root.label
                        font.weight: Font.Medium
                        font.features: { "tnum": 1 }
                    }
                }
            }
        }
    }
}
