import QtQuick
import QtQuick.Layouts
import qs.common
import qs.common.widgets
import qs.services

// Presentation and viewing modes.
ColumnLayout {
    spacing: 24

    Section {
        icon: "co_present"
        title: Translation.tr("Presentation")

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
    }

    Section {
        icon: "movie"
        title: Translation.tr("Viewing")

        SwitchRow {
            icon: "movie"
            title: Translation.tr("Viewing mode when a video fills the screen")
            subtitle: Translation.tr("A fullscreen window with something playing hides the bar and holds notifications, and keeps the screen on")
            checked: Config.options.viewing.auto
            onToggled: checked => Config.options.viewing.auto = checked
        }
    }
}
