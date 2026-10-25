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
        title: "Weather"

        SwitchRow { icon: "cloud"; title: "Weather"; checked: o.weather.enabled; onToggled: checked => o.weather.enabled = checked }
        TextRow {
            icon: "location_on"
            title: "City"
            subtitle: Weather.city ? `Now: ${Weather.city}` : "Empty = locate by IP (a VPN changes the result)"
            value: o.weather.city
            placeholder: "e.g. Moscow"
            onEdited: text => o.weather.city = text.trim()
        }
        SwitchRow { icon: "thermostat"; title: "Fahrenheit and mph"; checked: o.weather.imperial; onToggled: checked => o.weather.imperial = checked }
        SliderRow { icon: "update"; title: "Refresh every"; value: o.weather.refreshMinutes; from: 5; to: 120; step: 5; suffix: " min"; onMoved: value => o.weather.refreshMinutes = value }
    }

    Section {
        icon: "battery_alert"
        title: "Battery"

        SwitchRow { icon: "notifications"; title: "Low battery warnings"; checked: o.battery.warnings; onToggled: checked => o.battery.warnings = checked }
        SliderRow { icon: "battery_3_bar"; title: "Low"; value: o.battery.low; from: 5; to: 50; suffix: "%"; onMoved: value => o.battery.low = value }
        SliderRow { icon: "battery_1_bar"; title: "Critical"; value: o.battery.critical; from: 2; to: 25; suffix: "%"; onMoved: value => o.battery.critical = value }
    }

    Section {
        icon: "notifications"
        title: "Notifications"

        SwitchRow { icon: "do_not_disturb_on"; title: "Do not disturb"; checked: Notifications.dnd; onToggled: checked => Notifications.dnd = checked }
        SliderRow { icon: "timer"; title: "Popup timeout"; value: o.notifications.defaultTimeout / 1000; from: 2; to: 20; suffix: " s"; onMoved: value => o.notifications.defaultTimeout = value * 1000 }
        SliderRow { icon: "history"; title: "History size"; value: o.notifications.historyLimit; from: 10; to: 300; step: 10; onMoved: value => o.notifications.historyLimit = value }
    }

    Section {
        icon: "system_update_alt"
        title: "Updates"

        SwitchRow { icon: "update"; title: "Check for updates"; checked: o.updates.enabled; onToggled: checked => o.updates.enabled = checked }
        SwitchRow { icon: "deployed_code"; title: "Include AUR"; subtitle: Updates.aurHelper ? `via ${Updates.aurHelper}` : "yay or paru not found"; checked: o.updates.aur; onToggled: checked => o.updates.aur = checked }
        SliderRow { icon: "schedule"; title: "Check every"; value: o.updates.intervalMinutes; from: 10; to: 360; step: 10; suffix: " min"; onMoved: value => o.updates.intervalMinutes = value }
    }

    Section {
        icon: "public"
        title: "Online wallpapers"

        TextRow {
            icon: "key"
            title: "Unsplash access key"
            subtitle: "Free at unsplash.com/developers; enables Unsplash in the picker"
            value: o.wallpapers.unsplashKey
            secret: true
            fieldWidth: 300
            onEdited: text => o.wallpapers.unsplashKey = text.trim()
        }
        TextRow {
            icon: "key"
            title: "Wallhaven API key"
            subtitle: "Optional"
            value: o.wallpapers.wallhavenKey
            secret: true
            fieldWidth: 300
            onEdited: text => o.wallpapers.wallhavenKey = text.trim()
        }
        TextRow {
            icon: "folder"
            title: "Wallpaper folders"
            subtitle: "Comma separated"
            value: o.wallpapers.directories.join(", ")
            fieldWidth: 300
            onEdited: text => {
                o.wallpapers.directories = text.split(",").map(d => d.trim()).filter(d => d);
                Wallpapers.scan();
            }
        }
    }
}
