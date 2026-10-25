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
        title: "Desktop"

        SwitchRow { icon: "wallpaper"; title: "Draw the wallpaper"; subtitle: "Turn off if another tool (swww, hyprpaper) draws it"; checked: root.d.wallpaper; onToggled: checked => root.d.wallpaper = checked }
        SwitchRow { icon: "widgets"; title: "Widgets"; checked: root.d.widgets; onToggled: checked => root.d.widgets = checked }
        SwitchRow { icon: "graphic_eq"; title: "Visualizer while music plays"; subtitle: "Needs cava"; checked: root.d.visualizer; onToggled: checked => root.d.visualizer = checked }
        ChoiceRow {
            icon: "monitor"
            title: "Widgets on"
            value: root.d.monitor
            options: [{ value: "", text: "First screen" }, ...Quickshell.screens.map(s => ({ value: s.name, text: s.name }))]
            onSelected: value => root.d.monitor = value
        }
        ListRow {
            Layout.fillWidth: true
            icon: "dashboard_customize"
            title: "Arrange widgets"
            subtitle: "Or right-click the desktop"
            M3Button {
                tonal: true
                text: "Edit layout"
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
                    text: DesktopLayout.names[modelData]
                    selected: DesktopLayout.entry(root.d.layout, modelData).enabled
                    onClicked: root.setEnabled(modelData, !selected)
                }
            }
        }
    }

    Section {
        icon: "crop_free"
        title: "Wallpaper frame"

        Flow {
            Layout.fillWidth: true
            Layout.margins: 12
            spacing: 6
            Repeater {
                model: [["", "None"], ["sunny", "Sunny"], ["cookie9", "Cookie"], ["flower", "Flower"], ["clover4", "Clover"], ["blob", "Blob"], ["arch", "Arch"], ["square", "Square"]]
                Chip {
                    required property var modelData
                    text: modelData[1]
                    selected: Config.options.wallpapers.frame === modelData[0]
                    onClicked: Config.options.wallpapers.frame = modelData[0]
                }
            }
        }
        TextRow {
            icon: "image"
            title: "Image frame widget picture"
            subtitle: "Empty = the wallpaper"
            value: root.d.image
            fieldWidth: 300
            placeholder: "~/Pictures/photo.jpg"
            onEdited: text => root.d.image = text.replace(/^~/, Paths.home)
        }
    }

    Section {
        icon: "public"
        title: "World clock"

        TextRow {
            icon: "schedule"
            title: "Time zones"
            subtitle: "IANA names, comma separated"
            value: root.d.worldClocks.join(", ")
            fieldWidth: 380
            onEdited: text => root.d.worldClocks = text.split(",").map(z => z.trim()).filter(z => z)
        }
    }
}
