import QtQuick
import QtQuick.Layouts
import qs.common
import qs.common.widgets
import qs.services

// Event sounds: on / off, the pack (a not yet downloaded one is fetched when picked), the volume,
// which groups of events make a sound, and a button to hear each event.
ColumnLayout {
    readonly property var s: Config.options.sounds
    spacing: 24

    Component.onCompleted: Sounds.refresh()

    Section {
        icon: "volume_up"
        title: Translation.tr("Sounds")

        SwitchRow {
            icon: "notifications_active"
            title: Translation.tr("Event sounds")
            subtitle: Translation.tr("Notifications, timers, battery, screenshots")
            checked: s.enabled
            onToggled: checked => s.enabled = checked
        }
        SliderRow {
            visible: s.enabled
            icon: "volume_down"
            title: Translation.tr("Volume")
            value: s.volume
            from: 0.1; to: 1; step: 0.05; decimals: 2
            onMoved: value => s.volume = value
        }
    }

    Section {
        visible: s.enabled
        icon: "library_music"
        title: Translation.tr("Sound pack")

        ChoiceRow {
            icon: "graphic_eq"
            title: Translation.tr("Pack")
            subtitle: Sounds.installing !== "" ? Translation.tr("Downloading…")
                    : Sounds.failed ? Translation.tr("Couldn't download the pack")
                    : Sounds.downloadable.includes(s.pack) ? "" : Translation.tr("The system sound theme")
            value: s.pack
            options: [{ value: "freedesktop", text: Translation.tr("System") }, { value: "miui", text: "MIUI" }, { value: "samsung", text: "Samsung" }]
            onSelected: value => {
                if (value === "freedesktop" || Sounds.installed.includes(value)) {
                    s.pack = value;
                    Sounds.play("notification", true);
                } else {
                    Sounds.install(value);
                }
            }
        }
        ListRow {
            visible: Sounds.downloadable.includes(s.pack) || Sounds.installing !== ""
            icon: "info"
            title: Translation.tr("MIUI and Samsung sounds belong to Xiaomi and Samsung")
            subtitle: Translation.tr("They are downloaded to ~/.local/share/hi-shell/sounds when picked, not shipped with the shell")
        }
    }

    Section {
        visible: s.enabled
        icon: "tune"
        title: Translation.tr("Events")

        SwitchRow {
            icon: "notifications"
            title: Translation.tr("Notifications")
            checked: s.notifications
            onToggled: checked => s.notifications = checked
        }
        SwitchRow {
            icon: "timer"
            title: Translation.tr("Timers and focus")
            checked: s.timers
            onToggled: checked => s.timers = checked
        }
        SwitchRow {
            icon: "battery_alert"
            title: Translation.tr("Battery and charger")
            checked: s.battery
            onToggled: checked => s.battery = checked
        }
        SwitchRow {
            icon: "screenshot_region"
            title: Translation.tr("Screenshots")
            checked: s.capture
            onToggled: checked => s.capture = checked
        }
    }

    Section {
        visible: s.enabled
        icon: "play_circle"
        title: Translation.tr("Listen")

        Repeater {
            model: Object.keys(Sounds.events)
            ListRow {
                required property string modelData
                Layout.fillWidth: true
                icon: "play_arrow"
                title: Translation.tr(Sounds.events[modelData][2])
                clickable: true
                onClicked: Sounds.play(modelData, true)
            }
        }
    }
}
