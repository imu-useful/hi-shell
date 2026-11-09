import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.common
import qs.services
import qs.common.widgets
import "BarWidgets.js" as BarWidgets

// Bar layout (widgets per section), position, style and per-widget options.
ColumnLayout {
    id: root

    readonly property var bar: Config.options.bar
    spacing: 24

    // Which bar the layout and style rows edit: "main" (the defaults), "screen:<name>" (the main bar on one screen,
    // its own settings over the defaults) or "extra:<id>" (another bar).
    property string target: "main"
    readonly property bool isMain: target === "main"
    readonly property bool isScreen: target.startsWith("screen:")
    readonly property bool isExtra: target.startsWith("extra:")
    readonly property string targetName: target.slice(target.indexOf(":") + 1)
    readonly property var extraBars: Config.options.bar.extra ?? []
    readonly property var monitorOverrides: Config.options.bar.monitors ?? {}
    // A target that was removed or whose screen was unplugged falls back to the main bar.
    onExtraBarsChanged: if (isExtra && !extraBars.some(b => b.id === targetName)) target = "main"

    // The effective value of a setting of the target bar, and writing one.
    function tget(key) {
        if (isMain)
            return Config.options.bar[key];
        if (key === "monitors")
            return (extraBars.find(b => b.id === targetName) ?? {}).monitors ?? [];
        return BarLayout.spec(isScreen ? targetName : "", isScreen ? "main" : targetName)[key];
    }
    function tset(key, value) {
        if (isMain)
            Config.options.bar[key] = value;
        else if (isScreen)
            Config.mapSet("bar.monitors", targetName + "." + key, value);
        else {
            const entry = extraBars.find(b => b.id === targetName);
            if (entry)
                Config.listPut("bar.extra", Object.assign({}, entry, { [key]: value }));
        }
    }
    // Widget copies: new ones start with these options.
    readonly property var copyDefaults: ({
        zoneClock: { zone: "Europe/London", label: "" },
        resources: { shown: ["cpu"] },
        utilButtons: { shown: ["screenshot"] },
        workspaces: { shown: 5 },
        media: { maxWidth: 160 },
        script: { command: "date +%H:%M", interval: 30, icon: "terminal" }
    })
    property string newCopyType: "zoneClock"
    property string newCopyName: ""
    readonly property string newCopyId: newCopyType + "#" + newCopyName.trim().replace(/[^A-Za-z0-9_-]/g, "")
    function addCopy() {
        if (newCopyName.trim() === "" || (Config.options.bar.instances ?? {})[newCopyId] !== undefined)
            return;
        Config.mapSet("bar.instances", newCopyId, copyDefaults[newCopyType]);
        newCopyName = "";
    }
    function addExtraBar() {
        let n = 2;
        while (extraBars.some(b => b.id === "bar" + n))
            n++;
        Config.listPut("bar.extra", { id: "bar" + n, position: "bottom", center: ["workspaces"] });
        target = "extra:bar" + n;
    }
    function removeTarget() {
        const t = target;
        target = "main";
        if (t.startsWith("extra:"))
            Config.listDel("bar.extra", t.slice(6));
        else if (t.startsWith("screen:"))
            Config.mapSet("bar.monitors", t.slice(7), null);
    }

    component LayoutSection: ColumnLayout {
        id: section

        required property string key
        required property string label
        property int selected: -1
        property bool adding: false
        readonly property var items: root.tget(key)

        function write(list) {
            root.tset(key, list);
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
                    icon: BarWidgets.icons[modelData.split("#")[0]] ?? "widgets"
                    text: BarWidgets.names[modelData] ? Translation.tr(BarWidgets.names[modelData]) : modelData
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
                model: [...Object.keys(BarWidgets.names), ...UserWidgets.names, ...Object.keys(Config.options.bar.instances ?? {})].filter(id => id === "divider" || id === "zoneClock" || id === "script" ? true : !section.items.includes(id))

                Chip {
                    required property string modelData
                    icon: "add"
                    text: BarWidgets.names[modelData] ? Translation.tr(BarWidgets.names[modelData]) : modelData
                    onClicked: section.write([...section.items, modelData])
                }
            }
        }
    }

    Section {
        icon: "dock_to_bottom"
        title: Translation.tr("Which bar")

        Flow {
            Layout.fillWidth: true
            Layout.margins: 10
            spacing: 6

            Chip {
                icon: "toolbar"
                text: Translation.tr("Main bar")
                selected: root.isMain
                onClicked: root.target = "main"
            }
            Repeater {
                model: Quickshell.screens

                Chip {
                    required property var modelData
                    icon: root.monitorOverrides[modelData.name] ? "tv_gen" : "tv"
                    text: modelData.name
                    selected: root.target === "screen:" + modelData.name
                    onClicked: root.target = "screen:" + modelData.name
                }
            }
            Repeater {
                model: root.extraBars

                Chip {
                    required property var modelData
                    icon: "dock_to_bottom"
                    text: modelData.id
                    selected: root.target === "extra:" + modelData.id
                    onClicked: root.target = "extra:" + modelData.id
                }
            }
            Chip {
                icon: "add"
                text: Translation.tr("Add a bar")
                onClicked: root.addExtraBar()
            }
        }
        StyledText {
            Layout.fillWidth: true
            Layout.margins: 14
            Layout.topMargin: 0
            wrapMode: Text.WordWrap
            text: root.isMain ? Translation.tr("The main bar is on every screen. Pick a screen to give it a bar of its own, or add another bar.")
                : root.isScreen ? Translation.tr("Settings changed here are only for this screen; the rest comes from the main bar.")
                : Translation.tr("Another bar. Keep the clock (the Dynamic Island) in one bar only.")
            font.pixelSize: Appearance.font.size.labelMedium
            color: Colors.m3onSurfaceVariant
        }
        SwitchRow {
            visible: root.isScreen
            icon: "visibility"
            title: Translation.tr("Show the bar on this screen")
            checked: (root.monitorOverrides[root.targetName] ?? {}).enabled !== false
            onToggled: checked => Config.mapSet("bar.monitors", root.targetName + ".enabled", checked ? null : false)
        }
        ListRow {
            visible: root.isExtra
            Layout.fillWidth: true
            icon: "tv"
            title: Translation.tr("Screens")
            Repeater {
                model: Quickshell.screens

                Chip {
                    required property var modelData
                    readonly property var listed: Array.from(root.tget("monitors") ?? [])
                    readonly property var names: Quickshell.screens.map(x => x.name)
                    text: modelData.name
                    selected: listed.length === 0 || listed.includes(modelData.name)
                    onClicked: {
                        const now = listed.length === 0 ? names : listed;
                        const next = selected ? now.filter(n => n !== modelData.name) : [...now, modelData.name];
                        if (next.length > 0)
                            root.tset("monitors", next.length === names.length ? [] : next);
                    }
                }
            }
        }
        M3Button {
            visible: !root.isMain && (root.isExtra || root.monitorOverrides[root.targetName] !== undefined)
            Layout.margins: 14
            tonal: true
            text: root.isExtra ? Translation.tr("Remove this bar") : Translation.tr("Use the main bar's settings")
            onClicked: root.removeTarget()
        }
    }

    Section {
        icon: "view_week"
        title: Translation.tr("Bar layout")

        M3Button {
            Layout.margins: 14
            tonal: true
            icon: "drag_pan"
            text: Translation.tr("Edit on the bar")
            onClicked: {
                ShellState.settingsOpen = false;
                ShellState.barEdit = true;
            }
        }
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
            value: root.tget("position")
            options: [
                { value: "top", text: Translation.tr("Top"), icon: "arrow_upward" },
                { value: "left", text: Translation.tr("Left"), icon: "arrow_back" },
                { value: "bottom", text: Translation.tr("Bottom"), icon: "arrow_downward" },
                { value: "right", text: Translation.tr("Right"), icon: "arrow_forward" }
            ]
            onSelected: value => root.tset("position", value)
        }
        ChoiceRow {
            icon: "style"
            title: Translation.tr("Style")
            value: root.tget("style")
            options: [
                { value: "hug", text: Translation.tr("Hug") },
                { value: "float", text: Translation.tr("Float") },
                { value: "islands", text: Translation.tr("Islands") },
                { value: "m3", text: "M3" }
            ]
            onSelected: value => root.tset("style", value)
        }
        ListRow {
            visible: root.isMain
            icon: "pets"
            title: Translation.tr("Logo")
            subtitle: Translation.tr("The button at the start of the bar. Auto is this system's distribution")
        }
        LogoPicker {
            visible: root.isMain
            Layout.fillWidth: true
            Layout.leftMargin: 16
            Layout.rightMargin: 16
            current: root.bar.logo
            onPicked: name => root.bar.logo = name
        }
        SliderRow {
            icon: "height"
            title: Translation.tr("Thickness")
            value: root.tget("height")
            from: 32
            to: 60
            suffix: Translation.tr(" px")
            onMoved: value => root.tset("height", value)
        }
        SliderRow {
            icon: "padding"
            title: Translation.tr("Gap to the screen edge")
            subtitle: Translation.tr("Float and Islands styles")
            value: root.tget("margin")
            from: 0
            to: 20
            suffix: Translation.tr(" px")
            onMoved: value => root.tset("margin", value)
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
        StepperRow {
            icon: "stacks"
            title: Translation.tr("Apps per workspace")
            subtitle: Translation.tr("How many app icons a workspace shows; the rest are counted as +N")
            value: root.bar.workspaces.appsPerWorkspace
            from: 1
            to: 6
            onChanged: value => root.bar.workspaces.appsPerWorkspace = value
        }
        ChoiceRow {
            icon: "swipe_right_alt"
            title: Translation.tr("Workspace switching")
            subtitle: Translation.tr("Stretch: the pill stretches over the slots in between, like a snake")
            value: root.bar.workspaces.switchStyle
            options: [{ value: "slide", text: Translation.tr("Slide") }, { value: "stretch", text: Translation.tr("Stretch") }]
            onSelected: value => root.bar.workspaces.switchStyle = value
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

    Section {
        icon: "extension"
        title: Translation.tr("Your own widgets")

        StyledText {
            Layout.fillWidth: true
            Layout.margins: 14
            Layout.bottomMargin: 0
            wrapMode: Text.WordWrap
            text: Translation.tr("A QML file in the widgets folder is a widget with the file's name; add it to a section above. Saving the file updates the bar. A widget made of a command needs no file: make a Script copy below.")
            font.pixelSize: Appearance.font.size.labelMedium
            color: Colors.m3onSurfaceVariant
        }
        Repeater {
            model: UserWidgets.names

            ListRow {
                required property string modelData
                readonly property var info: UserWidgets.widgets[modelData]
                Layout.fillWidth: true
                icon: info.error ? "error" : "extension"
                title: modelData
                subtitle: info.error ? info.error.split("\n")[0] : info.file
            }
        }
        StyledText {
            visible: UserWidgets.names.length === 0
            Layout.margins: 14
            text: Translation.tr("No widgets yet. `hi widgets new <name>` makes one.")
            color: Colors.m3outline
        }
        RowLayout {
            Layout.margins: 14
            spacing: 8

            M3Button {
                tonal: true
                icon: "folder_open"
                text: Translation.tr("Open the folder")
                onClicked: UserWidgets.openFolder()
            }
            M3Button {
                tonal: true
                icon: "refresh"
                text: Translation.tr("Reload")
                onClicked: UserWidgets.reload()
            }
        }
    }

    Section {
        icon: "content_copy"
        title: Translation.tr("Widget copies")

        StyledText {
            Layout.fillWidth: true
            Layout.margins: 14
            Layout.bottomMargin: 0
            wrapMode: Text.WordWrap
            text: Translation.tr("A copy of a widget with options of its own, e.g. a second resources widget showing only the disk, or the time in Tokyo. Add it to a section above like any widget. Options are JSON.")
            font.pixelSize: Appearance.font.size.labelMedium
            color: Colors.m3onSurfaceVariant
        }
        Repeater {
            model: Object.keys(Config.options.bar.instances ?? {})

            RowLayout {
                required property string modelData
                Layout.fillWidth: true
                spacing: 4

                TextRow {
                    Layout.fillWidth: true
                    icon: BarWidgets.icons[modelData.split("#")[0]] ?? "widgets"
                    title: modelData
                    value: JSON.stringify((Config.options.bar.instances ?? {})[modelData] ?? {})
                    fieldWidth: 300
                    onEdited: text => {
                        try {
                            const v = JSON.parse(text);
                            if (v !== null && typeof v === "object" && !Array.isArray(v))
                                Config.mapSet("bar.instances", modelData, v);
                        } catch (e) {}
                    }
                }
                IconButton {
                    icon: "delete"
                    onClicked: Config.mapSet("bar.instances", modelData, null)
                }
            }
        }
        ChoiceRow {
            icon: "widgets"
            title: Translation.tr("New copy of")
            value: root.newCopyType
            options: Object.keys(root.copyDefaults).map(k => ({ value: k, text: Translation.tr(BarWidgets.names[k] ?? k) }))
            onSelected: value => root.newCopyType = value
        }
        TextRow {
            icon: "label"
            title: Translation.tr("Name")
            subtitle: Translation.tr("Letters and digits; the copy is called %1").arg(root.newCopyId)
            placeholder: "tokyo"
            value: root.newCopyName
            fieldWidth: 160
            onEdited: text => root.newCopyName = text
        }
        M3Button {
            Layout.margins: 14
            tonal: true
            icon: "add"
            text: Translation.tr("Add the copy")
            enabled: root.newCopyName.trim() !== ""
            onClicked: root.addCopy()
        }
    }

    Section {
        icon: "circle_notifications"
        title: Translation.tr("Dynamic Island")

        SwitchRow {
            icon: "circle_notifications"
            title: Translation.tr("Dynamic Island")
            subtitle: Translation.tr("The clock in the bar also shows music, notifications and the camera or microphone, and floats over a fullscreen window")
            checked: root.bar.island.enabled
            onToggled: checked => root.bar.island.enabled = checked
        }
        SliderRow {
            visible: Config.options.settingsAdvanced
            enabled: root.bar.island.enabled
            icon: "timer"
            title: Translation.tr("Hold to switch")
            subtitle: Translation.tr("How long to hold the island (or the clock) to switch its state")
            value: root.bar.island.holdDuration / 1000
            from: 0.5
            to: 5
            step: 0.5
            decimals: 1
            suffix: Translation.tr(" s")
            onMoved: value => root.bar.island.holdDuration = Math.round(value * 1000)
        }
        SwitchRow {
            enabled: root.bar.island.enabled
            icon: "unfold_less"
            title: Translation.tr("Clear the bar")
            subtitle: Translation.tr("While the island shows music or a notification the other widgets leave: the left ones go right, the right ones go left")
            checked: root.bar.island.hideBar
            onToggled: checked => root.bar.island.hideBar = checked
        }
        SwitchRow {
            enabled: root.bar.island.enabled
            icon: "music_note"
            title: Translation.tr("Music player")
            subtitle: Translation.tr("A hold switches between the clock and the player; a tap opens its controls")
            checked: root.bar.island.music
            onToggled: checked => root.bar.island.music = checked
        }
        SwitchRow {
            enabled: root.bar.island.enabled
            icon: "notifications"
            title: Translation.tr("Notifications")
            subtitle: Translation.tr("Instead of popup cards; hover for the message and buttons")
            checked: root.bar.island.notifications
            onToggled: checked => root.bar.island.notifications = checked
        }
        SwitchRow {
            enabled: root.bar.island.enabled
            icon: "volume_up"
            title: Translation.tr("Volume and brightness")
            subtitle: Translation.tr("Volume, brightness, microphone and keyboard layout changes appear in the island, not as a separate pill")
            checked: root.bar.island.osd
            onToggled: checked => root.bar.island.osd = checked
        }
        SwitchRow {
            enabled: root.bar.island.enabled
            icon: "mic"
            title: Translation.tr("Camera and microphone indicator")
            subtitle: Translation.tr("Green: microphone, orange: camera, yellow: both")
            checked: root.bar.island.privacy
            onToggled: checked => root.bar.island.privacy = checked
        }
        SwitchRow {
            enabled: root.bar.island.enabled
            icon: "fullscreen"
            title: Translation.tr("Over fullscreen windows")
            subtitle: Translation.tr("The island floats at the top of the screen for notifications and the indicator")
            checked: root.bar.island.fullscreen
            onToggled: checked => root.bar.island.fullscreen = checked
        }
    }
}
