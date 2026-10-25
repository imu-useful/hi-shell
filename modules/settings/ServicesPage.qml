import QtQuick
import QtQuick.Layouts
import qs.common
import qs.common.widgets
import qs.services

// Weather, battery, notifications, updates, online wallpapers.
ColumnLayout {
    readonly property var o: Config.options
    spacing: 24

    Section {
        icon: "partly_cloudy_day"
        title: Translation.tr("Weather")

        SwitchRow { icon: "cloud"; title: Translation.tr("Weather"); checked: o.weather.enabled; onToggled: checked => o.weather.enabled = checked }
        TextRow {
            icon: "location_on"
            title: Translation.tr("City")
            subtitle: Weather.city ? Translation.tr("Now: %1").arg(Weather.city) : Translation.tr("Empty = locate by IP (a VPN changes the result)")
            value: o.weather.city
            placeholder: Translation.tr("e.g. Moscow")
            onEdited: text => o.weather.city = text.trim()
        }
        SwitchRow { icon: "thermostat"; title: Translation.tr("Fahrenheit and mph"); checked: o.weather.imperial; onToggled: checked => o.weather.imperial = checked }
        SliderRow { icon: "update"; title: Translation.tr("Refresh every"); value: o.weather.refreshMinutes; from: 5; to: 120; step: 5; suffix: Translation.tr(" min"); onMoved: value => o.weather.refreshMinutes = value }
    }

    Section {
        icon: "battery_alert"
        title: Translation.tr("Battery")

        SwitchRow { icon: "notifications"; title: Translation.tr("Low battery warnings"); checked: o.battery.warnings; onToggled: checked => o.battery.warnings = checked }
        SliderRow { icon: "battery_3_bar"; title: Translation.tr("Low"); value: o.battery.low; from: 5; to: 50; suffix: "%"; onMoved: value => o.battery.low = value }
        SliderRow { icon: "battery_1_bar"; title: Translation.tr("Critical"); value: o.battery.critical; from: 2; to: 25; suffix: "%"; onMoved: value => o.battery.critical = value }
    }

    Section {
        icon: "notifications"
        title: Translation.tr("Notifications")

        SwitchRow { icon: "do_not_disturb_on"; title: Translation.tr("Do not disturb"); checked: Notifications.dnd; onToggled: checked => Notifications.dnd = checked }
        SliderRow { icon: "timer"; title: Translation.tr("Popup timeout"); value: o.notifications.defaultTimeout / 1000; from: 2; to: 20; suffix: " " + Translation.tr("s"); onMoved: value => o.notifications.defaultTimeout = value * 1000 }
        SliderRow { icon: "history"; title: Translation.tr("History size"); value: o.notifications.historyLimit; from: 10; to: 300; step: 10; onMoved: value => o.notifications.historyLimit = value }
    }

    Section {
        icon: "system_update_alt"
        title: Translation.tr("Updates")

        SwitchRow { icon: "update"; title: Translation.tr("Check for updates"); checked: o.updates.enabled; onToggled: checked => o.updates.enabled = checked }
        SwitchRow { icon: "deployed_code"; title: Translation.tr("Include AUR"); subtitle: Updates.aurHelper ? Translation.tr("via %1").arg(Updates.aurHelper) : Translation.tr("yay or paru not found"); checked: o.updates.aur; onToggled: checked => o.updates.aur = checked }
        SliderRow { icon: "schedule"; title: Translation.tr("Check every"); value: o.updates.intervalMinutes; from: 10; to: 360; step: 10; suffix: Translation.tr(" min"); onMoved: value => o.updates.intervalMinutes = value }
    }

    Section {
        icon: "public"
        title: Translation.tr("Online wallpapers")

        TextRow {
            icon: "key"
            title: Translation.tr("Unsplash access key")
            subtitle: Translation.tr("Free at unsplash.com/developers; enables Unsplash in the picker")
            value: o.wallpapers.unsplashKey
            secret: true
            fieldWidth: 300
            onEdited: text => o.wallpapers.unsplashKey = text.trim()
        }
        TextRow {
            icon: "key"
            title: Translation.tr("Wallhaven API key")
            subtitle: Translation.tr("Optional")
            value: o.wallpapers.wallhavenKey
            secret: true
            fieldWidth: 300
            onEdited: text => o.wallpapers.wallhavenKey = text.trim()
        }
        TextRow {
            icon: "folder"
            title: Translation.tr("Wallpaper folders")
            subtitle: Translation.tr("Comma separated")
            value: o.wallpapers.directories.join(", ")
            fieldWidth: 300
            onEdited: text => {
                o.wallpapers.directories = text.split(",").map(d => d.trim()).filter(d => d);
                Wallpapers.scan();
            }
        }
    }
}
