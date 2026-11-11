import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.common
import qs.common.widgets
import qs.services

// Notification popups, do not disturb and the history.
ColumnLayout {
    id: root

    readonly property var o: Config.options
    spacing: 24

    Section {
        icon: "notifications"
        title: Translation.tr("Notifications")

        SwitchRow { icon: "do_not_disturb_on"; title: Translation.tr("Do not disturb"); checked: Notifications.dnd; onToggled: checked => Notifications.dnd = checked }
        SliderRow { icon: "timer"; title: Translation.tr("Popup timeout"); value: o.notifications.defaultTimeout / 1000; from: 2; to: 20; suffix: " " + Translation.tr("s"); onMoved: value => o.notifications.defaultTimeout = value * 1000 }
        SwitchRow { icon: "hourglass_top"; title: Translation.tr("Hold notifications in Focus Mode"); subtitle: Translation.tr("They wait for the break instead of popping up"); checked: o.notifications.holdInFocus; onToggled: checked => o.notifications.holdInFocus = checked }
        SliderRow { visible: Config.options.settingsAdvanced; icon: "history"; title: Translation.tr("History size"); value: o.notifications.historyLimit; from: 10; to: 300; step: 10; onMoved: value => o.notifications.historyLimit = value }
    }
}
