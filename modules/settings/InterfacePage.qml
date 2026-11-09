import QtQuick
import QtQuick.Layouts
import qs.common
import qs.common.widgets
import qs.services

// Fonts, motion, transparency, sidebars.
ColumnLayout {
    readonly property var a: Config.options.appearance
    spacing: 24

    Section {
        icon: "format_paint"
        title: Translation.tr("App themes")

        SwitchRow {
            icon: "web_asset"
            title: Translation.tr("GTK apps")
            subtitle: Translation.tr("The wallpaper's colors in GTK 3 / 4 apps (a block in ~/.config/gtk-3.0 and gtk-4.0 gtk.css; off removes it)")
            checked: Config.options.appThemes.gtk
            onToggled: checked => Config.options.appThemes.gtk = checked
        }
        SwitchRow {
            icon: "terminal"
            title: Translation.tr("Neovim")
            subtitle: Translation.tr("Writes the hi-shell color scheme: use :colorscheme hi-shell in Neovim")
            checked: Config.options.appThemes.neovim
            onToggled: checked => Config.options.appThemes.neovim = checked
        }
        StyledText {
            Layout.fillWidth: true
            Layout.margins: 14
            Layout.topMargin: 0
            wrapMode: Text.WordWrap
            text: Translation.tr("Terminals, btop, fish and starship follow the palette without a switch.")
            font.pixelSize: Appearance.font.size.labelMedium
            color: Colors.m3onSurfaceVariant
        }
    }

    Section {
        icon: "text_fields"
        title: Translation.tr("Fonts")

        TextRow { icon: "font_download"; title: Translation.tr("Interface"); value: a.fonts.main; onEdited: text => a.fonts.main = text || "Google Sans Flex" }
        TextRow { icon: "title"; title: Translation.tr("Titles"); value: a.fonts.title; onEdited: text => a.fonts.title = text || "Google Sans Flex" }
        TextRow { icon: "code"; title: Translation.tr("Monospace"); value: a.fonts.mono; onEdited: text => a.fonts.mono = text || "JetBrains Mono" }
    }

    Section {
        icon: "straighten"
        title: Translation.tr("Shape & size")

        ChoiceRow {
            icon: "density_medium"
            title: Translation.tr("Density")
            subtitle: Translation.tr("The spacing between and inside elements")
            value: a.density
            options: [{ value: "compact", text: Translation.tr("Compact") }, { value: "comfortable", text: Translation.tr("Comfortable") }, { value: "spacious", text: Translation.tr("Spacious") }]
            onSelected: value => a.density = value
        }
        SliderRow {
            icon: "rounded_corner"
            title: Translation.tr("Corner roundness")
            subtitle: Translation.tr("0 makes every corner square")
            value: Math.round(a.cornerScale * 100)
            from: 0; to: 200; step: 5; suffix: "%"
            onMoved: value => a.cornerScale = value / 100
        }
        SliderRow {
            icon: "format_size"
            title: Translation.tr("Text size")
            value: Math.round(a.fontScale * 100)
            from: 60; to: 200; step: 5; suffix: "%"
            onMoved: value => a.fontScale = value / 100
        }
    }

    Section {
        icon: "palette"
        title: Translation.tr("Palette")

        TextRow {
            icon: "colorize"
            title: Translation.tr("Seed color")
            subtitle: Translation.tr("A color like #ff6a00 to make the palette from; empty = from the wallpaper")
            placeholder: "#ff6a00"
            value: a.seedColor
            onEdited: text => {
                const t = text.trim();
                a.seedColor = t === "" || /^#[0-9a-fA-F]{6}$/.test(t) ? t : a.seedColor;
            }
        }
        SliderRow {
            icon: "contrast"
            title: Translation.tr("Contrast")
            value: Math.round(a.contrast * 100)
            from: -100; to: 100; step: 10; suffix: "%"
            onMoved: value => a.contrast = value / 100
        }
        M3Button {
            Layout.margins: 14
            text: Translation.tr("Reset shape, size and palette")
            onClicked: ["cornerScale", "fontScale", "density", "seedColor", "contrast"].forEach(k => Config.reset("appearance." + k))
        }
    }

    Section {
        icon: "right_panel_open"
        title: Translation.tr("Right sidebar")

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

    Section {
        icon: "animation"
        title: Translation.tr("Motion & surfaces")

        SliderRow {
            icon: "speed"
            title: Translation.tr("Animation speed")
            subtitle: Translation.tr("0 turns animations off")
            value: a.animationSpeed
            from: 0; to: 2; step: 0.1; decimals: 1; suffix: "×"
            onMoved: value => a.animationSpeed = value
        }
        SwitchRow {
            icon: "blur_on"
            title: Translation.tr("Transparency")
            checked: a.transparency
            onToggled: checked => a.transparency = checked
        }
        SliderRow {
            visible: a.transparency
            icon: "opacity"
            title: Translation.tr("Panel transparency")
            value: Math.round(a.transparencyLevel * 100)
            from: 0; to: 50; suffix: "%"
            onMoved: value => a.transparencyLevel = value / 100
        }
        SwitchRow {
            icon: "album"
            title: Translation.tr("Blurred cover behind the player")
            subtitle: Translation.tr("The playing track's cover, blurred, fills the media cards")
            checked: a.coverBackdrop
            onToggled: checked => a.coverBackdrop = checked
        }
        SwitchRow {
            icon: "palette"
            title: Translation.tr("Themed app icons")
            subtitle: Translation.tr("The apps' icons in one color, the wallpaper's primary: in the dock, the bar's workspaces and the launcher")
            checked: Config.options.appearance.themedIcons
            onToggled: checked => Config.options.appearance.themedIcons = checked
        }
        SwitchRow {
            icon: "movie"
            title: Translation.tr("Viewing mode when a video fills the screen")
            subtitle: Translation.tr("A fullscreen window with something playing hides the bar and holds notifications, and keeps the screen on")
            checked: Config.options.viewing.auto
            onToggled: checked => Config.options.viewing.auto = checked
        }
        SwitchRow {
            icon: "co_present"
            title: Translation.tr("Presentation mode")
            subtitle: Translation.tr("For sharing the screen: holds notifications, keeps the screen on, turns the night light off and hides the desktop widgets")
            checked: Presentation.active
            onToggled: checked => Presentation.set(checked)
        }
        SwitchRow {
            icon: "notifications_paused"
            title: Translation.tr("Presentation: hold notifications")
            checked: Config.options.presentation.holdNotifications
            onToggled: checked => Config.options.presentation.holdNotifications = checked
        }
        SwitchRow {
            icon: "coffee"
            title: Translation.tr("Presentation: keep the screen on")
            checked: Config.options.presentation.keepAwake
            onToggled: checked => Config.options.presentation.keepAwake = checked
        }
        SwitchRow {
            icon: "nightlight"
            title: Translation.tr("Presentation: night light off")
            checked: Config.options.presentation.nightLightOff
            onToggled: checked => Config.options.presentation.nightLightOff = checked
        }
        SwitchRow {
            icon: "widgets"
            title: Translation.tr("Presentation: hide the desktop widgets")
            checked: Config.options.presentation.hideDesktopWidgets
            onToggled: checked => Config.options.presentation.hideDesktopWidgets = checked
        }
        SwitchRow {
            icon: "web_asset_off"
            title: Translation.tr("Presentation: hide the bar")
            checked: Config.options.presentation.hideBar
            onToggled: checked => Config.options.presentation.hideBar = checked
        }
        ChoiceRow {
            icon: "menu_open"
            title: Translation.tr("Context menus")
            subtitle: Translation.tr("The tray's right-click menus")
            value: a.contextMenu
            options: [{ value: "material", text: Translation.tr("New") }, { value: "caelestia", text: "Caelestia" }, { value: "standard", text: Translation.tr("Standard") }]
            onSelected: value => a.contextMenu = value
        }
        SliderRow {
            icon: "rounded_corner"
            title: Translation.tr("Screen corners")
            subtitle: Translation.tr("0 turns them off")
            value: a.screenCorners
            from: 0; to: 32; suffix: Translation.tr(" px")
            onMoved: value => a.screenCorners = value
        }
    }

    Section {
        icon: "waving_hand"
        title: Translation.tr("Startup greeting")

        SwitchRow {
            icon: "waving_hand"
            title: Translation.tr("Greeting at startup")
            subtitle: Translation.tr("A black screen and a line of text when the shell starts. The very first start always has its own animation")
            checked: Config.options.greeting.enabled
            onToggled: checked => Config.options.greeting.enabled = checked
        }
        TextRow {
            visible: Config.options.greeting.enabled
            icon: "edit"
            title: Translation.tr("Text")
            placeholder: "Welcome back!"
            value: Config.options.greeting.text
            onEdited: text => Config.options.greeting.text = text.trim() || "Welcome back!"
        }
        ChoiceRow {
            visible: Config.options.greeting.enabled
            icon: "animation"
            title: Translation.tr("Animation")
            value: Config.options.greeting.style
            options: [
                { value: "random", text: Translation.tr("Random") },
                { value: "rise", text: Translation.tr("Rise") },
                { value: "drop", text: Translation.tr("Drop") },
                { value: "pop", text: Translation.tr("Pop") },
                { value: "slide", text: Translation.tr("Slide") },
                { value: "spin", text: Translation.tr("Spin") }
            ]
            onSelected: value => Config.options.greeting.style = value
        }
        SwitchRow {
            visible: Config.options.greeting.enabled
            icon: "emoji_symbols"
            title: Translation.tr("Logo")
            checked: Config.options.greeting.logo
            onToggled: checked => Config.options.greeting.logo = checked
        }
        ListRow {
            visible: Config.options.greeting.enabled
            icon: "play_arrow"
            title: Translation.tr("Preview")
            subtitle: Translation.tr("Play it now")
            clickable: true
            onClicked: ShellState.previewGreeting()
        }
    }

    Section {
        icon: "side_navigation"
        title: Translation.tr("Sidebars")

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
}
