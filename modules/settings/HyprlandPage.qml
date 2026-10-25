import QtQuick
import QtQuick.Layouts
import qs.common
import qs.common.widgets
import qs.services

// Displays (mode, orientation, scale, position), look & feel and input.
// Applied at once and kept in ~/.config/hi-shell/hyprland.lua.
ColumnLayout {
    id: root

    readonly property var monitors: HyprlandSettings.monitors
    property string selectedName: ""
    readonly property var selected: monitors.find(m => m.name === selectedName) ?? monitors[0] ?? null
    readonly property var v: HyprlandSettings.values

    Component.onCompleted: HyprlandSettings.refresh()
    spacing: 24

    Section {
        icon: "monitor"
        title: "Displays"

        // Arrangement preview, scaled to fit.
        Item {
            id: arrangement
            Layout.fillWidth: true
            Layout.margins: 10
            implicitHeight: 170

            readonly property var bounds: {
                let x0 = Infinity, y0 = Infinity, x1 = -Infinity, y1 = -Infinity;
                for (const m of root.monitors) {
                    const w = (m.transform % 2 ? m.height : m.width) / m.scale, h = (m.transform % 2 ? m.width : m.height) / m.scale;
                    x0 = Math.min(x0, m.x); y0 = Math.min(y0, m.y);
                    x1 = Math.max(x1, m.x + w); y1 = Math.max(y1, m.y + h);
                }
                return { x0, y0, w: x1 - x0, h: y1 - y0 };
            }
            readonly property real k: bounds.w > 0 ? Math.min((width - 20) / bounds.w, (height - 20) / bounds.h) : 1

            Repeater {
                model: root.monitors

                Rectangle {
                    required property var modelData
                    readonly property bool isSelected: root.selected === modelData
                    readonly property real lw: (modelData.transform % 2 ? modelData.height : modelData.width) / modelData.scale
                    readonly property real lh: (modelData.transform % 2 ? modelData.width : modelData.height) / modelData.scale

                    x: (arrangement.width - arrangement.bounds.w * arrangement.k) / 2 + (modelData.x - arrangement.bounds.x0) * arrangement.k
                    y: (arrangement.height - arrangement.bounds.h * arrangement.k) / 2 + (modelData.y - arrangement.bounds.y0) * arrangement.k
                    width: lw * arrangement.k - 4
                    height: lh * arrangement.k - 4
                    radius: Appearance.rounding.large
                    color: isSelected ? Colors.m3primaryContainer : Colors.m3surfaceContainerHighest
                    border.width: isSelected ? 2 : 0
                    border.color: Colors.m3primary

                    Column {
                        anchors.centerIn: parent
                        MaterialIcon {
                            anchors.horizontalCenter: parent.horizontalCenter
                            icon: "monitor"
                            color: isSelected ? Colors.m3onPrimaryContainer : Colors.m3onSurfaceVariant
                        }
                        StyledText {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: modelData.name
                            font.weight: Font.Medium
                            color: isSelected ? Colors.m3onPrimaryContainer : Colors.m3onSurface
                        }
                        StyledText {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: `${modelData.width}×${modelData.height}`
                            font.pixelSize: Appearance.font.size.labelSmall
                            color: isSelected ? Colors.m3onPrimaryContainer : Colors.m3onSurfaceVariant
                        }
                    }

                    StateLayer {
                        onClicked: root.selectedName = modelData.name
                    }
                }
            }
        }

        StyledText {
            Layout.leftMargin: 16
            visible: root.selected !== null
            text: root.selected ? `${root.selected.name} · ${root.selected.description}` : ""
            font.pixelSize: Appearance.font.size.labelMedium
            color: Colors.m3onSurfaceVariant
        }

        ListRow {
            Layout.fillWidth: true
            icon: "aspect_ratio"
            title: "Resolution & refresh rate"
            visible: root.selected !== null
        }
        Flow {
            Layout.fillWidth: true
            Layout.leftMargin: 16
            Layout.rightMargin: 16
            Layout.bottomMargin: 8
            visible: root.selected !== null
            spacing: 6

            Repeater {
                // "1920x1080@60.00Hz"
                model: root.selected?.availableModes ?? []

                Chip {
                    required property string modelData
                    readonly property string mode: modelData.replace("Hz", "")
                    readonly property bool active: root.selected && mode === `${root.selected.width}x${root.selected.height}@${root.selected.refreshRate.toFixed(2)}`
                    text: mode.replace("@", " · ") + " Hz"
                    selected: active
                    onClicked: HyprlandSettings.setMonitor(root.selected.name, { mode })
                }
            }
        }

        ChoiceRow {
            visible: root.selected !== null
            icon: "screen_rotation"
            title: "Orientation"
            value: root.selected?.transform ?? 0
            options: [
                { value: 0, text: "Normal" }, { value: 1, text: "90°" },
                { value: 2, text: "180°" }, { value: 3, text: "270°" }
            ]
            onSelected: value => HyprlandSettings.setMonitor(root.selected.name, { transform: value })
        }
        StepperRow {
            visible: root.selected !== null
            icon: "zoom_in"
            title: "Scale"
            value: root.selected?.scale ?? 1
            step: 0.25
            from: 0.5
            to: 3
            decimals: 2
            onChanged: value => HyprlandSettings.setMonitor(root.selected.name, { scale: value })
        }
        TextRow {
            visible: root.selected !== null
            icon: "open_with"
            title: "Position"
            subtitle: "Top-left corner in the layout, e.g. 1920x0"
            value: root.selected ? `${root.selected.x}x${root.selected.y}` : ""
            fieldWidth: 140
            onEdited: text => {
                if (/^-?\d+x-?\d+$/.test(text.trim()))
                    HyprlandSettings.setMonitor(root.selected.name, { position: text.trim() });
            }
        }
    }

    Section {
        icon: "rounded_corner"
        title: "Look & feel"

        SliderRow {
            icon: "border_inner"
            title: "Gaps between windows"
            value: root.v["general.gaps_in"] ?? 0
            from: 0; to: 30; suffix: " px"
            onMoved: value => HyprlandSettings.setOption("general.gaps_in", value)
        }
        SliderRow {
            icon: "border_outer"
            title: "Gaps to the screen edge"
            value: root.v["general.gaps_out"] ?? 0
            from: 0; to: 60; suffix: " px"
            onMoved: value => HyprlandSettings.setOption("general.gaps_out", value)
        }
        SliderRow {
            icon: "border_style"
            title: "Border size"
            value: root.v["general.border_size"] ?? 0
            from: 0; to: 6; suffix: " px"
            onMoved: value => HyprlandSettings.setOption("general.border_size", value)
        }
        SliderRow {
            icon: "rounded_corner"
            title: "Window rounding"
            value: root.v["decoration.rounding"] ?? 0
            from: 0; to: 30; suffix: " px"
            onMoved: value => HyprlandSettings.setOption("decoration.rounding", value)
        }
        SwitchRow {
            icon: "blur_on"
            title: "Blur"
            checked: root.v["decoration.blur.enabled"] ?? false
            onToggled: checked => HyprlandSettings.setOption("decoration.blur.enabled", checked)
        }
        SliderRow {
            visible: root.v["decoration.blur.enabled"] ?? false
            icon: "blur_medium"
            title: "Blur size"
            value: root.v["decoration.blur.size"] ?? 0
            from: 1; to: 20
            onMoved: value => HyprlandSettings.setOption("decoration.blur.size", value)
        }
        SliderRow {
            visible: root.v["decoration.blur.enabled"] ?? false
            icon: "layers"
            title: "Blur passes"
            value: root.v["decoration.blur.passes"] ?? 0
            from: 1; to: 6
            onMoved: value => HyprlandSettings.setOption("decoration.blur.passes", value)
        }
        SwitchRow {
            icon: "shadow"
            title: "Shadows"
            checked: root.v["decoration.shadow.enabled"] ?? false
            onToggled: checked => HyprlandSettings.setOption("decoration.shadow.enabled", checked)
        }
        SwitchRow {
            icon: "animation"
            title: "Animations"
            checked: root.v["animations.enabled"] ?? false
            onToggled: checked => HyprlandSettings.setOption("animations.enabled", checked)
        }
    }

    Section {
        icon: "mouse"
        title: "Input"

        SliderRow {
            icon: "speed"
            title: "Pointer sensitivity"
            value: root.v["input.sensitivity"] ?? 0
            from: -1; to: 1; step: 0.05; decimals: 2
            onMoved: value => HyprlandSettings.setOption("input.sensitivity", value)
        }
        SwitchRow {
            icon: "swipe_vertical"
            title: "Natural scrolling (touchpad)"
            checked: root.v["input.touchpad.natural_scroll"] ?? false
            onToggled: checked => HyprlandSettings.setOption("input.touchpad.natural_scroll", checked)
        }
        SwitchRow {
            icon: "ads_click"
            title: "Focus follows mouse"
            checked: (root.v["input.follow_mouse"] ?? 1) === 1
            onToggled: checked => HyprlandSettings.setOption("input.follow_mouse", checked ? 1 : 0)
        }
    }

    RowLayout {
        Layout.fillWidth: true
        StyledText {
            Layout.fillWidth: true
            text: `Saved in ${HyprlandSettings.luaFile.replace(Paths.home, "~")}`
            font.pixelSize: Appearance.font.size.labelMedium
            color: Colors.m3outline
        }
        M3Button {
            tonal: true
            icon: "restart_alt"
            text: "Reset Hyprland overrides"
            onClicked: HyprlandSettings.resetAll()
        }
    }
}
