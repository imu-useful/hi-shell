import QtQuick
import QtQuick.Layouts
import qs.common
import qs.common.widgets

// Fonts, motion, transparency, sidebars.
ColumnLayout {
    readonly property var a: Config.options.appearance
    spacing: 24

    Section {
        icon: "text_fields"
        title: Translation.tr("Fonts")

        TextRow { icon: "font_download"; title: Translation.tr("Interface"); value: a.fonts.main; onEdited: text => a.fonts.main = text || "Google Sans Flex" }
        TextRow { icon: "title"; title: Translation.tr("Titles"); value: a.fonts.title; onEdited: text => a.fonts.title = text || "Google Sans Flex" }
        TextRow { icon: "code"; title: Translation.tr("Monospace"); value: a.fonts.mono; onEdited: text => a.fonts.mono = text || "JetBrains Mono" }
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
        icon: "side_navigation"
        title: Translation.tr("Sidebars")

        ChoiceRow {
            icon: "toggle_on"
            title: Translation.tr("Quick toggles")
            value: Config.options.sidebar.quickToggles.style
            options: [{ value: "android", text: Translation.tr("Android") }, { value: "classic", text: Translation.tr("Classic") }]
            onSelected: value => Config.options.sidebar.quickToggles.style = value
        }
        ChoiceRow {
            icon: "sports_esports"
            title: Translation.tr("Game")
            subtitle: Translation.tr("In the empty notification center")
            value: Config.options.sidebar.game
            options: [{ value: "dino", text: Translation.tr("Dino") }, { value: "snake", text: Translation.tr("Snake") }, { value: "minesweeper", text: Translation.tr("Minesweeper") }]
            onSelected: value => Config.options.sidebar.game = value
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
