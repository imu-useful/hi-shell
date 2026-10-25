import QtQuick
import QtQuick.Layouts
import qs.common
import qs.common.widgets
import "BarWidgets.js" as BarWidgets

// Bar layout (widgets per section), position, style and per-widget options.
ColumnLayout {
    id: root

    readonly property var bar: Config.options.bar
    spacing: 24

    component LayoutSection: ColumnLayout {
        id: section

        required property string key
        required property string label
        property int selected: -1
        property bool adding: false
        readonly property list<string> items: Config.options.bar[key]

        function write(list) {
            Config.options.bar[key] = list;
        }

        Layout.fillWidth: true
        Layout.margins: 10
        spacing: 8

        RowLayout {
            Layout.fillWidth: true
            StyledText {
                Layout.fillWidth: true
                text: section.label
                font.weight: Font.Medium
            }
            // Move the selected widget left / right
            IconButton {
                visible: section.selected >= 0
                implicitWidth: 32
                implicitHeight: 32
                icon: "arrow_back"
                enabled: section.selected > 0
                onClicked: {
                    const l = [...section.items], i = section.selected;
                    [l[i - 1], l[i]] = [l[i], l[i - 1]];
                    section.write(l);
                    section.selected = i - 1;
                }
            }
            IconButton {
                visible: section.selected >= 0
                implicitWidth: 32
                implicitHeight: 32
                icon: "arrow_forward"
                enabled: section.selected >= 0 && section.selected < section.items.length - 1
                onClicked: {
                    const l = [...section.items], i = section.selected;
                    [l[i + 1], l[i]] = [l[i], l[i + 1]];
                    section.write(l);
                    section.selected = i + 1;
                }
            }
            IconButton {
                implicitWidth: 36
                implicitHeight: 36
                filled: section.adding
                icon: section.adding ? "close" : "add"
                onClicked: section.adding = !section.adding
            }
        }

        Flow {
            Layout.fillWidth: true
            spacing: 6

            Repeater {
                model: section.items

                Chip {
                    required property string modelData
                    required property int index
                    icon: BarWidgets.icons[modelData] ?? "widgets"
                    text: Translation.tr(BarWidgets.names[modelData] ?? modelData)
                    selected: section.selected === index
                    closable: true
                    onClicked: section.selected = section.selected === index ? -1 : index
                    onCloseClicked: {
                        section.write(section.items.filter((_, i) => i !== index));
                        section.selected = -1;
                    }
                }
            }

            StyledText {
                visible: section.items.length === 0
                text: Translation.tr("Empty")
                color: Colors.m3outline
            }
        }

        // Widgets that can be added here (dividers any number of times).
        Flow {
            Layout.fillWidth: true
            visible: section.adding
            spacing: 6

            Repeater {
                model: Object.keys(BarWidgets.names).filter(id => id === "divider" || !section.items.includes(id))

                Chip {
                    required property string modelData
                    icon: "add"
                    text: Translation.tr(BarWidgets.names[modelData])
                    onClicked: section.write([...section.items, modelData])
                }
            }
        }
    }

    Section {
        icon: "view_week"
        title: Translation.tr("Bar layout")

        LayoutSection { key: "left"; label: Translation.tr("Left") }
        LayoutSection { key: "center"; label: Translation.tr("Center") }
        LayoutSection { key: "right"; label: Translation.tr("Right") }
    }

    Section {
        icon: "tune"
        title: Translation.tr("Positioning & style")

        ChoiceRow {
            icon: "open_with"
            title: Translation.tr("Position")
            value: root.bar.position
            options: [
                { value: "top", text: Translation.tr("Top"), icon: "arrow_upward" },
                { value: "left", text: Translation.tr("Left"), icon: "arrow_back" },
                { value: "bottom", text: Translation.tr("Bottom"), icon: "arrow_downward" },
                { value: "right", text: Translation.tr("Right"), icon: "arrow_forward" }
            ]
            onSelected: value => root.bar.position = value
        }
        ChoiceRow {
            icon: "style"
            title: Translation.tr("Style")
            value: root.bar.style
            options: [
                { value: "hug", text: Translation.tr("Hug") },
                { value: "float", text: Translation.tr("Float") },
                { value: "islands", text: Translation.tr("Islands") },
                { value: "m3", text: "M3" }
            ]
            onSelected: value => root.bar.style = value
        }
        SliderRow {
            icon: "height"
            title: Translation.tr("Thickness")
            value: root.bar.height
            from: 32
            to: 60
            suffix: Translation.tr(" px")
            onMoved: value => root.bar.height = value
        }
        SliderRow {
            icon: "padding"
            title: Translation.tr("Gap to the screen edge")
            subtitle: Translation.tr("Float and Islands styles")
            value: root.bar.margin
            from: 0
            to: 20
            suffix: Translation.tr(" px")
            onMoved: value => root.bar.margin = value
        }
    }

    Section {
        icon: "widgets"
        title: Translation.tr("Widgets")

        StepperRow {
            icon: "grid_view"
            title: Translation.tr("Workspaces shown")
            value: root.bar.workspaces.shown
            from: 3
            to: 20
            onChanged: value => root.bar.workspaces.shown = value
        }
        SwitchRow {
            icon: "pin"
            title: Translation.tr("Workspace numbers")
            checked: root.bar.workspaces.numbers
            onToggled: checked => root.bar.workspaces.numbers = checked
        }
        SwitchRow {
            icon: "apps"
            title: Translation.tr("App icons on workspaces")
            checked: root.bar.workspaces.appIcons
            onToggled: checked => root.bar.workspaces.appIcons = checked
        }
        TextRow {
            icon: "schedule"
            title: Translation.tr("Time format")
            subtitle: Translation.tr("Qt format, e.g. HH:mm or h:mm AP")
            value: root.bar.clock.timeFormat
            fieldWidth: 160
            onEdited: text => root.bar.clock.timeFormat = text || "HH:mm"
        }
        TextRow {
            icon: "calendar_today"
            title: Translation.tr("Date format")
            subtitle: "e.g. ddd, dd/MM or d MMMM"
            value: root.bar.clock.dateFormat
            fieldWidth: 160
            onEdited: text => root.bar.clock.dateFormat = text
        }
        ListRow {
            Layout.fillWidth: true
            icon: "memory"
            title: Translation.tr("Resources")
            Repeater {
                model: ["cpu", "ram", "swap", "gpu", "disk"]
                Chip {
                    required property string modelData
                    text: modelData.toUpperCase()
                    selected: root.bar.resources.shown.includes(modelData)
                    onClicked: root.bar.resources.shown = selected ? root.bar.resources.shown.filter(x => x !== modelData) : [...root.bar.resources.shown, modelData]
                }
            }
        }
        ListRow {
            Layout.fillWidth: true
            icon: "build"
            title: Translation.tr("Util buttons")
            Repeater {
                model: [["screenshot", "screenshot_region"], ["colorPicker", "colorize"], ["wallpaper", "wallpaper"], ["darkMode", "dark_mode"], ["mic", "mic"]]
                Chip {
                    required property var modelData
                    icon: modelData[1]
                    text: ""
                    selected: root.bar.utilButtons.shown.includes(modelData[0])
                    onClicked: root.bar.utilButtons.shown = selected ? root.bar.utilButtons.shown.filter(x => x !== modelData[0]) : [...root.bar.utilButtons.shown, modelData[0]]
                }
            }
        }
        SliderRow {
            icon: "music_note"
            title: Translation.tr("Media width")
            value: root.bar.media.maxWidth
            from: 120
            to: 400
            step: 10
            suffix: Translation.tr(" px")
            onMoved: value => root.bar.media.maxWidth = value
        }
        SwitchRow {
            icon: "album"
            title: Translation.tr("Spin cover art while playing")
            subtitle: Translation.tr("Uses a little more CPU while music plays")
            checked: root.bar.media.spinArt
            onToggled: checked => root.bar.media.spinArt = checked
        }
        SwitchRow {
            icon: "system_update_alt"
            title: Translation.tr("Hide updates when there are none")
            checked: root.bar.updates.hideWhenNone
            onToggled: checked => root.bar.updates.hideWhenNone = checked
        }
    }
}
