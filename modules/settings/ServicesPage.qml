import QtQuick
import QtQuick.Layouts
import qs.common
import qs.common.widgets
import qs.services

// Weather, updates, screen capture and Spotify.
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
        TextRow {
            icon: "my_location"
            title: Translation.tr("Latitude")
            subtitle: Translation.tr("With longitude, instead of a city (0 and 0 = not set)")
            value: String(o.weather.latitude)
            fieldWidth: 120
            onEdited: text => { const v = Number(text.replace(",", ".")); if (!isNaN(v) && v >= -90 && v <= 90) o.weather.latitude = v; }
        }
        TextRow {
            icon: "my_location"
            title: Translation.tr("Longitude")
            value: String(o.weather.longitude)
            fieldWidth: 120
            onEdited: text => { const v = Number(text.replace(",", ".")); if (!isNaN(v) && v >= -180 && v <= 180) o.weather.longitude = v; }
        }
        SwitchRow { icon: "thermostat"; title: Translation.tr("Fahrenheit and mph"); checked: o.weather.imperial; onToggled: checked => o.weather.imperial = checked }
        SliderRow { visible: Config.options.settingsAdvanced; icon: "update"; title: Translation.tr("Refresh every"); value: o.weather.refreshMinutes; from: 5; to: 120; step: 5; suffix: Translation.tr(" min"); onMoved: value => o.weather.refreshMinutes = value }
    }

    Section {
        icon: "system_update_alt"
        title: Translation.tr("Updates")

        SwitchRow { icon: "update"; title: Translation.tr("Check for updates"); checked: o.updates.enabled; onToggled: checked => o.updates.enabled = checked }
        SwitchRow { icon: "deployed_code"; title: Translation.tr("Include AUR"); subtitle: Updates.aurHelper ? Translation.tr("via %1").arg(Updates.aurHelper) : Translation.tr("yay or paru not found"); checked: o.updates.aur; onToggled: checked => o.updates.aur = checked }
        SliderRow { visible: Config.options.settingsAdvanced; icon: "schedule"; title: Translation.tr("Check every"); value: o.updates.intervalMinutes; from: 10; to: 360; step: 10; suffix: Translation.tr(" min"); onMoved: value => o.updates.intervalMinutes = value }
    }

    Section {
        icon: "screenshot_region"
        title: Translation.tr("Screen capture")

        ChoiceRow {
            icon: "mic"
            title: Translation.tr("Sound in recordings")
            value: o.capture.recordSound
            options: [{ value: "off", text: Translation.tr("None") }, { value: "system", text: Translation.tr("System") }, { value: "mic", text: Translation.tr("Microphone") }]
            onSelected: value => o.capture.recordSound = value
        }
        TextRow {
            visible: Config.options.settingsAdvanced
            icon: "translate"
            title: Translation.tr("OCR languages")
            subtitle: Translation.tr("auto = every installed tesseract language, or e.g. eng+rus")
            value: o.capture.ocrLanguages
            fieldWidth: 160
            onEdited: text => o.capture.ocrLanguages = text.trim() || "auto"
        }
    }

    Section {
        icon: "music_note"
        title: Translation.tr("Spotify")

        TextRow {
            icon: "key"
            title: Translation.tr("Client ID")
            subtitle: Translation.tr("From developer.spotify.com/dashboard; redirect URI http://127.0.0.1:8888/callback")
            value: o.spotify.clientId
            fieldWidth: 300
            onEdited: text => o.spotify.clientId = text.trim()
        }
    }
}
