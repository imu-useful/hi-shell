import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.common
import qs.common.widgets
import qs.services

// Blocking adult sites and closing tabs by words in their title.
ColumnLayout {
    id: root

    readonly property var o: Config.options
    spacing: 24

    Section {
        icon: "shield"
        title: Translation.tr("Content filter")

        ListRow {
            Layout.fillWidth: true
            icon: "block"
            title: Translation.tr("Block adult sites")
            subtitle: AdultFilter.busy ? Translation.tr("Changing /etc/hosts…")
                : AdultFilter.error !== "" ? AdultFilter.error
                : AdultFilter.applied ? Translation.tr("On in every browser and app here, until it's switched off. The list: services/adult_domains.txt")
                : Translation.tr("Off. Switching it on or off asks for your password")
            M3Switch {
                id: adultSwitch
                enabled: !AdultFilter.busy
                // The click changes the switch itself: when the change doesn't happen, it goes back to the real state.
                Binding {
                    target: adultSwitch
                    property: "checked"
                    value: AdultFilter.applied
                    when: !AdultFilter.busy
                }
                onToggled: checked => AdultFilter.set(checked)
            }
        }
        SwitchRow {
            icon: "label"
            title: Translation.tr("Close tabs with these words in the title")
            subtitle: Translation.tr("A browser tab whose title has one of the words is closed (Ctrl+W), and a notice says so")
            checked: o.contentFilter.keywordsOn
            onToggled: checked => o.contentFilter.keywordsOn = checked
        }
        TextRow {
            icon: "spellcheck"
            title: Translation.tr("Words")
            subtitle: Translation.tr("Separated by commas. Matches anywhere in a title, in any case")
            value: o.contentFilter.keywords.join(", ")
            fieldWidth: 320
            onEdited: text => o.contentFilter.keywords = text.split(",").map(w => w.trim()).filter(w => w !== "")
        }
    }
}
