import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.common
import qs.common.widgets
import qs.services
import "../desktop/Layout.js" as DesktopLayout

// The desktop on each screen, the desktop widgets and the world clocks.
ColumnLayout {
    id: root

    readonly property var d: Config.options.desktop

    function setEnabled(id, enabled) {
        const layout = Object.assign({}, d.layout);
        layout[id] = Object.assign({}, DesktopLayout.entry(d.layout, id), { enabled });
        d.layout = layout;
    }

    spacing: 24

    // The names a list option (dock.monitors, desktop.monitors) holds after `screen` is turned on or off.
    // ["*"] = every screen; ["-"] = none (an empty list would mean "the first screen").
    function screensWith(list, legacy, screen, on) {
        const names = Quickshell.screens.filter(s => ScreenPrefs.selected(list, legacy, s)).map(s => s.name);
        const next = on ? [...new Set([...names, screen.name])] : names.filter(n => n !== screen.name);
        return next.length === Quickshell.screens.length ? ["*"] : next.length === 0 ? ["-"] : next;
    }

    Section {
        icon: "tv"
        title: Translation.tr("Screens")

        StyledText {
            Layout.fillWidth: true
            Layout.margins: 14
            Layout.bottomMargin: 0
            wrapMode: Text.WordWrap
            text: Translation.tr("What each screen shows: the desktop widgets (with a layout of its own if you like), the dock, and a wallpaper of its own. Bars have their own picker in Bar.")
            font.pixelSize: Appearance.font.size.labelMedium
            color: Colors.m3onSurfaceVariant
        }
        Repeater {
            model: Quickshell.screens

            ColumnLayout {
                id: block
                required property var modelData
                readonly property var dockOwn: (Config.options.dock.perScreen ?? {})[modelData.name] ?? {}
                Layout.fillWidth: true
                spacing: 0

                StyledText {
                    Layout.margins: 14
                    Layout.bottomMargin: 2
                    text: `${block.modelData.name} · ${block.modelData.width}×${block.modelData.height}`
                    font.weight: Font.Medium
                }
                SwitchRow {
                    icon: "widgets"
                    title: Translation.tr("Desktop widgets")
                    checked: ScreenPrefs.selected(root.d.monitors, root.d.monitor, block.modelData)
                    onToggled: checked => root.d.monitors = root.screensWith(root.d.monitors, root.d.monitor, block.modelData, checked)
                }
                SwitchRow {
                    visible: ScreenPrefs.selected(root.d.monitors, root.d.monitor, block.modelData)
                    icon: "dashboard_customize"
                    title: Translation.tr("Own widget layout")
                    subtitle: Translation.tr("Starts as a copy of the shared layout; edit it in the desktop's edit mode")
                    checked: ScreenPrefs.hasOwnLayout(block.modelData.name)
                    onToggled: checked => ScreenPrefs.setOwnLayout(block.modelData.name, checked)
                }
                SwitchRow {
                    icon: "dock_to_bottom"
                    title: Translation.tr("Dock")
                    checked: ScreenPrefs.selected(Config.options.dock.monitors, Config.options.dock.monitor, block.modelData)
                    onToggled: checked => Config.options.dock.monitors = root.screensWith(Config.options.dock.monitors, Config.options.dock.monitor, block.modelData, checked)
                }
                ChoiceRow {
                    visible: ScreenPrefs.selected(Config.options.dock.monitors, Config.options.dock.monitor, block.modelData)
                    icon: "open_with"
                    title: Translation.tr("Dock position")
                    value: ScreenPrefs.dockFor(block.modelData.name).position
                    options: [{ value: "bottom", text: Translation.tr("Bottom") }, { value: "top", text: Translation.tr("Top") }, { value: "left", text: Translation.tr("Left") }, { value: "right", text: Translation.tr("Right") }]
                    onSelected: value => Config.mapSet("dock.perScreen", block.modelData.name + ".position", value)
                }
                SliderRow {
                    visible: ScreenPrefs.selected(Config.options.dock.monitors, Config.options.dock.monitor, block.modelData)
                    icon: "photo_size_select_large"
                    title: Translation.tr("Dock icon size")
                    value: ScreenPrefs.dockFor(block.modelData.name).iconSize
                    from: 28; to: 72; suffix: Translation.tr(" px")
                    onMoved: value => Config.mapSet("dock.perScreen", block.modelData.name + ".iconSize", value)
                }
                M3Button {
                    visible: Object.keys(block.dockOwn).length > 0
                    Layout.margins: 14
                    tonal: true
                    text: Translation.tr("Use the shared dock settings")
                    onClicked: Config.mapSet("dock.perScreen", block.modelData.name, null)
                }
                TextRow {
                    icon: "wallpaper"
                    title: Translation.tr("Wallpaper")
                    subtitle: Translation.tr("A picture for this screen only (a path); empty = the shared wallpaper")
                    placeholder: "~/Pictures/Wallpapers/…"
                    value: ((Config.options.wallpapers.perScreen ?? {})[block.modelData.name]) ?? ""
                    fieldWidth: 280
                    onEdited: text => Config.mapSet("wallpapers.perScreen", block.modelData.name, text.trim() === "" ? null : text.trim())
                }
            }
        }
    }

    Section {
        icon: "widgets"
        title: Translation.tr("Widgets")

        SwitchRow { icon: "widgets"; title: Translation.tr("Widgets"); checked: root.d.widgets; onToggled: checked => root.d.widgets = checked }
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
        SwitchRow { icon: "graphic_eq"; title: Translation.tr("Visualizer while music plays"); subtitle: Translation.tr("Needs cava"); checked: root.d.visualizer; onToggled: checked => root.d.visualizer = checked }
        SwitchRow { icon: "timer"; title: Translation.tr("Seconds in the digital clock"); checked: root.d.clockSeconds; onToggled: checked => root.d.clockSeconds = checked }
        SwitchRow { icon: "waves"; title: Translation.tr("Wavy progress bar in the player"); subtitle: Translation.tr("Off: a plain bar"); checked: root.d.waveProgress; onToggled: checked => root.d.waveProgress = checked }
        SwitchRow { icon: "music_note"; title: Translation.tr("Wave kicks to the beat"); subtitle: Translation.tr("Needs cava"); enabled: root.d.waveProgress; checked: root.d.waveBeat; onToggled: checked => root.d.waveBeat = checked }
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
