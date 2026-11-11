import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.common
import qs.common.widgets
import qs.services

// Power saving and the battery warnings.
ColumnLayout {
    id: root

    readonly property var o: Config.options
    spacing: 24

    Section {
        icon: "battery_saver"
        title: Translation.tr("Power saving")

        SwitchRow {
            icon: "battery_saver"
            title: Translation.tr("Power saving mode")
            subtitle: Translation.tr("Turns off animations, blur, transparency, the visualizer, the dancing frame and cover mode; the weather is checked less often. Turning it off puts everything back.")
            checked: Config.options.powerSaving.enabled
            onToggled: checked => PowerSaver.apply(checked)
        }
    }

    Section {
        icon: "battery_alert"
        title: Translation.tr("Battery")

        SwitchRow { icon: "notifications"; title: Translation.tr("Low battery warnings"); checked: o.battery.warnings; onToggled: checked => o.battery.warnings = checked }
        SliderRow { icon: "battery_3_bar"; title: Translation.tr("Low"); value: o.battery.low; from: 5; to: 50; suffix: "%"; onMoved: value => o.battery.low = value }
        SliderRow { icon: "battery_1_bar"; title: Translation.tr("Critical"); value: o.battery.critical; from: 2; to: 25; suffix: "%"; onMoved: value => o.battery.critical = value }
    }
}
