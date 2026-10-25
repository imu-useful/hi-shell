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
        title: "Fonts"

        TextRow { icon: "font_download"; title: "Interface"; value: a.fonts.main; onEdited: text => a.fonts.main = text || "Google Sans Flex" }
        TextRow { icon: "title"; title: "Titles"; value: a.fonts.title; onEdited: text => a.fonts.title = text || "Google Sans Flex" }
        TextRow { icon: "code"; title: "Monospace"; value: a.fonts.mono; onEdited: text => a.fonts.mono = text || "JetBrains Mono" }
    }

    Section {
        icon: "animation"
        title: "Motion & surfaces"

        SliderRow {
            icon: "speed"
            title: "Animation speed"
            subtitle: "0 turns animations off"
            value: a.animationSpeed
            from: 0; to: 2; step: 0.1; decimals: 1; suffix: "×"
            onMoved: value => a.animationSpeed = value
        }
        SwitchRow {
            icon: "blur_on"
            title: "Transparency"
            checked: a.transparency
            onToggled: checked => a.transparency = checked
        }
        SliderRow {
            visible: a.transparency
            icon: "opacity"
            title: "Panel transparency"
            value: Math.round(a.transparencyLevel * 100)
            from: 0; to: 50; suffix: "%"
            onMoved: value => a.transparencyLevel = value / 100
        }
    }

    Section {
        icon: "side_navigation"
        title: "Sidebars"

        ChoiceRow {
            icon: "toggle_on"
            title: "Quick toggles"
            value: Config.options.sidebar.quickToggles.style
            options: [{ value: "android", text: "Android" }, { value: "classic", text: "Classic" }]
            onSelected: value => Config.options.sidebar.quickToggles.style = value
        }
        SliderRow {
            icon: "nightlight"
            title: "Night light temperature"
            value: Config.options.sidebar.nightLightTemperature
            from: 2500; to: 6000; step: 100; suffix: " K"
            onMoved: value => Config.options.sidebar.nightLightTemperature = value
        }
    }
}
