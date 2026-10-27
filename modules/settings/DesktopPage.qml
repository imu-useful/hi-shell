import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.common
import qs.common.widgets
import "../desktop/Layout.js" as DesktopLayout

// Desktop layer: wallpaper, widgets, frame, world clocks, visualizer.
ColumnLayout {
    id: root

    readonly property var d: Config.options.desktop

    function setEnabled(id, enabled) {
        const layout = Object.assign({}, d.layout);
        layout[id] = Object.assign({}, DesktopLayout.entry(d.layout, id), { enabled });
        d.layout = layout;
    }

    spacing: 24

    Section {
        icon: "desktop_windows"
        title: Translation.tr("Desktop")

        SwitchRow { icon: "wallpaper"; title: Translation.tr("Draw the wallpaper"); subtitle: Translation.tr("Turn off if another tool (swww, hyprpaper) draws it"); checked: root.d.wallpaper; onToggled: checked => root.d.wallpaper = checked }
        SwitchRow {
            icon: "layers_clear"
            title: Translation.tr("Clean desktop")
            subtitle: Translation.tr("With windows open: sharp wallpaper, widgets and frame hidden")
            checked: root.d.focusMode
            onToggled: checked => root.d.focusMode = checked
        }
        SwitchRow {
            icon: "album"
            title: Translation.tr("Cover mode")
            subtitle: Translation.tr("The playing track's cover instead of the wallpaper, colors included")
            checked: root.d.coverMode
            onToggled: checked => root.d.coverMode = checked
        }
        SwitchRow { icon: "widgets"; title: Translation.tr("Widgets"); checked: root.d.widgets; onToggled: checked => root.d.widgets = checked }
        SwitchRow { icon: "graphic_eq"; title: Translation.tr("Visualizer while music plays"); subtitle: Translation.tr("Needs cava"); checked: root.d.visualizer; onToggled: checked => root.d.visualizer = checked }
        SwitchRow { icon: "timer"; title: Translation.tr("Seconds in the digital clock"); checked: root.d.clockSeconds; onToggled: checked => root.d.clockSeconds = checked }
        ChoiceRow {
            icon: "monitor"
            title: Translation.tr("Widgets on")
            value: root.d.monitor
            options: [{ value: "", text: Translation.tr("First screen") }, ...Quickshell.screens.map(s => ({ value: s.name, text: s.name }))]
            onSelected: value => root.d.monitor = value
        }
        ListRow {
            Layout.fillWidth: true
            icon: "dashboard_customize"
            title: Translation.tr("Arrange widgets")
            subtitle: Translation.tr("Or right-click the desktop")
            M3Button {
                tonal: true
                text: Translation.tr("Edit layout")
                onClicked: {
                    ShellState.settingsOpen = false;
                    ShellState.desktopEditing = true;
                }
            }
        }
        Flow {
            Layout.fillWidth: true
            Layout.margins: 12
            spacing: 6
            Repeater {
                model: DesktopLayout.ids
                Chip {
                    required property string modelData
                    text: Translation.tr(DesktopLayout.names[modelData])
                    selected: DesktopLayout.entry(root.d.layout, modelData).enabled
                    onClicked: root.setEnabled(modelData, !selected)
                }
            }
        }
    }

    Section {
        icon: "dock_to_bottom"
        title: Translation.tr("Dock")

        SwitchRow { icon: "dock_to_bottom"; title: Translation.tr("Dock"); checked: Config.options.dock.enabled; onToggled: checked => Config.options.dock.enabled = checked }
        SwitchRow { icon: "visibility_off"; title: Translation.tr("Hide until the pointer reaches the bottom edge"); checked: Config.options.dock.autoHide; onToggled: checked => Config.options.dock.autoHide = checked }
        SwitchRow { icon: "zoom_in"; title: Translation.tr("Magnify on hover"); checked: Config.options.dock.magnify; onToggled: checked => Config.options.dock.magnify = checked }
        SliderRow { icon: "photo_size_select_large"; title: Translation.tr("Icon size"); value: Config.options.dock.iconSize; from: 28; to: 72; suffix: Translation.tr(" px"); onMoved: value => Config.options.dock.iconSize = value }
    }

    Section {
        icon: "crop_free"
        title: Translation.tr("Wallpaper frame")

        FramePicker {
            Layout.fillWidth: true
            Layout.margins: 12
            current: Config.options.wallpapers.frame
            onPicked: id => Config.options.wallpapers.frame = id
        }
        ListRow {
            Layout.fillWidth: true
            icon: "open_with"
            title: Translation.tr("Move the frame")
            subtitle: Translation.tr("Drag it on the desktop, in edit mode")
            M3Button {
                tonal: true
                visible: Config.options.wallpapers.frameX !== 0.5 || Config.options.wallpapers.frameY !== 0.5
                text: Translation.tr("Center")
                onClicked: {
                    Config.options.wallpapers.frameX = 0.5;
                    Config.options.wallpapers.frameY = 0.5;
                }
            }
            M3Button {
                tonal: true
                text: Translation.tr("Move")
                onClicked: {
                    ShellState.settingsOpen = false;
                    ShellState.desktopEditing = true;
                }
            }
        }
        SwitchRow {
            icon: "graphic_eq"
            title: Translation.tr("Move to the music")
            subtitle: Translation.tr("The frame turns and pulses to the bass while something plays")
            checked: Config.options.wallpapers.frameDance
            onToggled: checked => Config.options.wallpapers.frameDance = checked
        }
        TextRow {
            icon: "image"
            title: Translation.tr("Image frame widget picture")
            subtitle: Translation.tr("Empty = the wallpaper")
            value: root.d.image
            fieldWidth: 300
            placeholder: "~/Pictures/photo.jpg"
            onEdited: text => root.d.image = text.replace(/^~/, Paths.home)
        }
    }

    Section {
        icon: "public"
        title: Translation.tr("World clock")

        TextRow {
            icon: "schedule"
            title: Translation.tr("Time zones")
            subtitle: Translation.tr("IANA names, comma separated")
            value: root.d.worldClocks.join(", ")
            fieldWidth: 380
            onEdited: text => root.d.worldClocks = text.split(",").map(z => z.trim()).filter(z => z)
        }
    }
}
