import QtQuick
import QtQuick.Layouts
import qs.common
import qs.common.widgets
import qs.services

// What the sidebars show, and what the launcher searches.
ColumnLayout {
    spacing: 24

    Section {
        icon: "side_navigation"
        title: Translation.tr("Sidebars")

        StyledText {
            Layout.fillWidth: true
            Layout.margins: 14
            Layout.bottomMargin: 0
            wrapMode: Text.WordWrap
            text: Translation.tr("What the sidebar shows under its header, and in what order")
            font.pixelSize: Appearance.font.size.labelMedium
            color: Colors.m3onSurfaceVariant
        }
        OrderedChips {
            options: [
                { id: "quickToggles", text: Translation.tr("Quick toggles"), icon: "toggle_on" },
                { id: "quickSliders", text: Translation.tr("Sliders"), icon: "tune" },
                { id: "tabs", text: Translation.tr("Tabs"), icon: "tab" }
            ]
            minimum: 0
            value: Config.options.sidebar.sections
            onChanged: list => Config.options.sidebar.sections = list
        }
        StyledText {
            Layout.fillWidth: true
            Layout.margins: 14
            Layout.bottomMargin: 0
            wrapMode: Text.WordWrap
            text: Translation.tr("Tabs")
            font.weight: Font.Medium
        }
        OrderedChips {
            options: [
                { id: "notifications", text: Translation.tr("Notifications"), icon: "notifications" },
                { id: "calendar", text: Translation.tr("Calendar"), icon: "calendar_month" },
                { id: "todo", text: Translation.tr("To-do"), icon: "checklist" },
                { id: "timers", text: Translation.tr("Timers"), icon: "timer" }
            ]
            value: Config.options.sidebar.tabs
            onChanged: list => Config.options.sidebar.tabs = list
        }
        ChoiceRow {
            icon: "toggle_on"
            title: Translation.tr("Quick toggles")
            value: Config.options.sidebar.quickToggles.style
            options: [{ value: "android", text: Translation.tr("Android") }, { value: "classic", text: Translation.tr("Classic") }]
            onSelected: value => Config.options.sidebar.quickToggles.style = value
        }
        StepperRow {
            visible: Config.options.sidebar.quickToggles.style !== "classic"
            icon: "pages"
            title: Translation.tr("Tiles per page")
            subtitle: Config.options.sidebar.quickToggles.perPage > 0 ? Translation.tr("The rest go to the next page") : Translation.tr("Off: 0, all on one page")
            value: Config.options.sidebar.quickToggles.perPage
            step: 2
            from: 0
            to: 20
            onChanged: value => Config.options.sidebar.quickToggles.perPage = value
        }
        SwitchRow {
            icon: "swipe"
            title: Translation.tr("Slide between pages")
            checked: Config.options.sidebar.quickToggles.slide
            onToggled: checked => Config.options.sidebar.quickToggles.slide = checked
        }
        // Too many games for one segmented button: the title row, then the games wrapped below it.
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 0

            ListRow {
                Layout.fillWidth: true
                icon: "sports_esports"
                title: Translation.tr("Game")
                subtitle: Translation.tr("In the empty notification center")
            }
            Flow {
                Layout.fillWidth: true
                Layout.leftMargin: 50
                Layout.rightMargin: 12
                Layout.bottomMargin: 10
                spacing: 6

                Repeater {
                    model: [{ value: "dino", text: Translation.tr("Dino") }, { value: "snake", text: Translation.tr("Snake") }, { value: "minesweeper", text: Translation.tr("Minesweeper") }, { value: "game2048", text: "2048" }, { value: "flappy", text: Translation.tr("Flappy") }, { value: "memory", text: Translation.tr("Memory") }, { value: "tictactoe", text: Translation.tr("Tic-tac-toe") }, { value: "puzzle", text: Translation.tr("15 puzzle") }, { value: "lightsout", text: Translation.tr("Lights out") }]

                    Chip {
                        required property var modelData
                        text: modelData.text
                        selected: Config.options.sidebar.game === modelData.value
                        onClicked: Config.options.sidebar.game = modelData.value
                    }
                }
            }
        }
        SliderRow {
            icon: "nightlight"
            title: Translation.tr("Night light temperature")
            value: Config.options.sidebar.nightLightTemperature
            from: 2500; to: 6000; step: 100; suffix: " K"
            onMoved: value => Config.options.sidebar.nightLightTemperature = value
        }
    }

    Section {
        icon: "search"
        title: Translation.tr("Launcher")

        StyledText {
            Layout.fillWidth: true
            Layout.margins: 14
            Layout.bottomMargin: 0
            wrapMode: Text.WordWrap
            text: Translation.tr("What a plain search looks through, in the order of the results")
            font.pixelSize: Appearance.font.size.labelMedium
            color: Colors.m3onSurfaceVariant
        }
        OrderedChips {
            options: [
                { id: "math", text: Translation.tr("Calculator"), icon: "calculate" },
                { id: "focus", text: Translation.tr("Focus Mode"), icon: "target" },
                { id: "windows", text: Translation.tr("Open windows"), icon: "web_asset" },
                { id: "settings", text: Translation.tr("Settings"), icon: "settings" },
                { id: "apps", text: Translation.tr("Apps"), icon: "apps" },
                { id: "emoji", text: Translation.tr("Emoji"), icon: "mood" }
            ]
            value: Config.options.launcher.sources
            onChanged: list => Config.options.launcher.sources = list
        }
        StyledText {
            Layout.fillWidth: true
            Layout.margins: 14
            Layout.bottomMargin: 0
            wrapMode: Text.WordWrap
            text: Translation.tr("Prefixes: a first character that switches the search to one source")
            font.pixelSize: Appearance.font.size.labelMedium
            color: Colors.m3onSurfaceVariant
        }
        OrderedChips {
            minimum: 0
            options: [
                { id: "=", text: "=  " + Translation.tr("Calculator"), icon: "calculate" },
                { id: ">", text: ">  " + Translation.tr("Run command"), icon: "terminal" },
                { id: "<", text: "<  " + Translation.tr("Keybinds"), icon: "keyboard" },
                { id: ":", text: ":  " + Translation.tr("Emoji"), icon: "mood" },
                { id: ";", text: ";  " + Translation.tr("Clipboard"), icon: "content_paste" },
                { id: "/", text: "/  " + Translation.tr("Settings"), icon: "settings" },
                { id: "~", text: "~  " + Translation.tr("Files"), icon: "folder" }
            ]
            value: Config.options.launcher.prefixes
            onChanged: list => Config.options.launcher.prefixes = list
        }
        M3Button {
            Layout.margins: 14
            tonal: true
            text: Translation.tr("Reset the sidebar and launcher")
            onClicked: ["sidebar.sections", "sidebar.tabs", "launcher"].forEach(k => Config.reset(k))
        }
    }
}
