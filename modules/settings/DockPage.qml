import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.common
import qs.common.widgets
import qs.services

// The dock: where, when and how it shows.
ColumnLayout {
    id: root

    spacing: 24

    Section {
        icon: "dock_to_bottom"
        title: Translation.tr("Dock")

        SwitchRow { icon: "dock_to_bottom"; title: Translation.tr("Dock"); checked: Config.options.dock.enabled; onToggled: checked => Config.options.dock.enabled = checked }
        ChoiceRow {
            icon: "open_with"
            title: Translation.tr("Dock position")
            value: Config.options.dock.position
            options: [{ value: "bottom", text: Translation.tr("Bottom") }, { value: "top", text: Translation.tr("Top") }, { value: "left", text: Translation.tr("Left") }, { value: "right", text: Translation.tr("Right") }]
            onSelected: value => Config.options.dock.position = value
        }
        SwitchRow { icon: "visibility_off"; title: Translation.tr("Hide until the pointer reaches the screen edge"); checked: Config.options.dock.autoHide; onToggled: checked => Config.options.dock.autoHide = checked }
        SwitchRow { icon: "desktop_windows"; title: Translation.tr("Show on an empty workspace"); checked: Config.options.dock.showWhenEmpty; onToggled: checked => Config.options.dock.showWhenEmpty = checked }
        SwitchRow { icon: "apps"; title: Translation.tr("Apps button"); subtitle: Translation.tr("Opens the full-screen list of every app"); checked: Config.options.dock.appsButton; onToggled: checked => Config.options.dock.appsButton = checked }
        SwitchRow { icon: "apps"; title: Translation.tr("Show running apps that aren't pinned"); checked: Config.options.dock.showRunning; onToggled: checked => Config.options.dock.showRunning = checked }
        SwitchRow { icon: "more_horiz"; title: Translation.tr("Window dots under the icons"); checked: Config.options.dock.showIndicators; onToggled: checked => Config.options.dock.showIndicators = checked }
        SwitchRow { icon: "zoom_in"; title: Translation.tr("Magnify on hover"); checked: Config.options.dock.magnify; onToggled: checked => Config.options.dock.magnify = checked }
        SliderRow { visible: Config.options.settingsAdvanced; icon: "zoom_out_map"; title: Translation.tr("Magnify amount"); value: Config.options.dock.magnifyAmount; from: 10; to: 100; suffix: "%"; onMoved: value => Config.options.dock.magnifyAmount = value }
        SliderRow { visible: Config.options.settingsAdvanced; icon: "space_bar"; title: Translation.tr("Gap between icons"); value: Config.options.dock.spacing; from: 0; to: 20; suffix: Translation.tr(" px"); onMoved: value => Config.options.dock.spacing = value }
        SliderRow { visible: Config.options.settingsAdvanced; icon: "rounded_corner"; title: Translation.tr("Corner radius"); value: Config.options.dock.cornerRadius; from: 0; to: 40; suffix: Translation.tr(" px"); onMoved: value => Config.options.dock.cornerRadius = value }
        SliderRow { visible: Config.options.settingsAdvanced; icon: "vertical_align_bottom"; title: Translation.tr("Distance from the screen edge"); value: Config.options.dock.edgeMargin; from: 0; to: 40; suffix: Translation.tr(" px"); onMoved: value => Config.options.dock.edgeMargin = value }
        SliderRow { icon: "photo_size_select_large"; title: Translation.tr("Icon size"); value: Config.options.dock.iconSize; from: 28; to: 72; suffix: Translation.tr(" px"); onMoved: value => Config.options.dock.iconSize = value }
    }
}
