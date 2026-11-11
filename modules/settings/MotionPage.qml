import QtQuick
import QtQuick.Layouts
import qs.common
import qs.common.widgets
import qs.services

// Animation speed and feel, how panels appear, and the startup greeting.
ColumnLayout {
    readonly property var a: Config.options.appearance
    spacing: 24

    Section {
        icon: "animation"
        title: Translation.tr("Motion")

        SliderRow {
            icon: "speed"
            title: Translation.tr("Animation speed")
            subtitle: Translation.tr("0 turns animations off")
            value: a.animationSpeed
            from: 0; to: 2; step: 0.1; decimals: 1; suffix: "×"
            onMoved: value => a.animationSpeed = value
        }
        ChoiceRow {
            icon: "animation"
            title: Translation.tr("Motion style")
            subtitle: Translation.tr("Springy, gentle or quick")
            value: a.motionStyle
            options: [{ value: "expressive", text: Translation.tr("Expressive") }, { value: "smooth", text: Translation.tr("Smooth") }, { value: "snappy", text: Translation.tr("Snappy") }]
            onSelected: value => a.motionStyle = value
        }
        SliderRow {
            icon: "waves"
            title: Translation.tr("Spring")
            subtitle: Translation.tr("How far panels overshoot; 0 is none")
            value: Math.round(a.animationBounce * 100)
            from: 0; to: 200; step: 10; suffix: "%"
            onMoved: value => a.animationBounce = value / 100
        }
        SwitchRow {
            icon: "water_drop"
            title: Translation.tr("Ripple")
            subtitle: Translation.tr("A wave grows from where you press")
            checked: a.ripple
            onToggled: checked => a.ripple = checked
        }
        SliderRow {
            icon: "touch_app"
            title: Translation.tr("Press squeeze")
            subtitle: Translation.tr("How much a pressed button shrinks; 0% is not at all")
            value: Math.round((1 - a.pressScale) * 100)
            from: 0; to: 30; step: 1; suffix: "%"
            onMoved: value => a.pressScale = 1 - value / 100
        }
        SliderRow {
            icon: "palette"
            title: Translation.tr("Color fade")
            subtitle: Translation.tr("How long colors take to change to a new palette; 0 is at once")
            value: a.paletteFade
            from: 0; to: 1500; step: 50; suffix: " ms"
            onMoved: value => a.paletteFade = value
        }
        ChoiceRow {
            icon: "open_in_full"
            title: Translation.tr("Popup effect")
            subtitle: Translation.tr("How the calendar, weather, AI and overview appear")
            value: a.popupEffect
            options: [{ value: "pop", text: Translation.tr("Pop") }, { value: "drop", text: Translation.tr("Drop") }, { value: "slide", text: Translation.tr("Slide") }, { value: "fade", text: Translation.tr("Fade") }]
            onSelected: value => a.popupEffect = value
        }
        ChoiceRow {
            icon: "apps"
            title: Translation.tr("Launcher effect")
            subtitle: Translation.tr("How the launcher appears")
            value: a.launcherEffect
            options: [{ value: "rise", text: Translation.tr("Rise") }, { value: "pop", text: Translation.tr("Pop") }, { value: "fade", text: Translation.tr("Fade") }]
            onSelected: value => a.launcherEffect = value
        }
        ChoiceRow {
            icon: "side_navigation"
            title: Translation.tr("Sidebar effect")
            subtitle: Translation.tr("How the side panels appear")
            value: a.sidebarEffect
            options: [{ value: "slide", text: Translation.tr("Slide") }, { value: "pop", text: Translation.tr("Pop") }, { value: "fade", text: Translation.tr("Fade") }]
            onSelected: value => a.sidebarEffect = value
        }
        SliderRow {
            visible: Config.options.settingsAdvanced
            icon: "dock_to_left"
            title: Translation.tr("Panels speed")
            subtitle: Translation.tr("Sidebars, popups and the launcher")
            value: Math.round(a.panelSpeed * 100)
            from: 25; to: 400; step: 25; suffix: "%"
            onMoved: value => a.panelSpeed = value / 100
        }
        SliderRow {
            visible: Config.options.settingsAdvanced
            icon: "toolbar"
            title: Translation.tr("Bar speed")
            subtitle: Translation.tr("The workspace indicator")
            value: Math.round(a.barSpeed * 100)
            from: 25; to: 400; step: 25; suffix: "%"
            onMoved: value => a.barSpeed = value / 100
        }
        SliderRow {
            visible: Config.options.settingsAdvanced
            icon: "notifications"
            title: Translation.tr("Notifications speed")
            subtitle: Translation.tr("How fast notification cards move")
            value: Math.round(a.notificationSpeed * 100)
            from: 25; to: 400; step: 25; suffix: "%"
            onMoved: value => a.notificationSpeed = value / 100
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
}
