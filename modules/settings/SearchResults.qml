import QtQuick
import QtQuick.Layouts
import qs.common
import qs.common.widgets
import "Pages.js" as Pages
import "OptionIndex.js" as OptionIndex

// What the search in Settings finds: pages, and the options (by name and description) with the page they are on.
ColumnLayout {
    id: root

    property string query: ""
    signal picked(string page, bool advanced)

    readonly property var words: query.toLowerCase().trim().split(/\s+/).filter(w => w)
    readonly property var pageHits: Pages.search(query, Translation.tr)
    readonly property var optionHits: OptionIndex.options.filter(o => {
        const hay = `${o.path} ${o.text} ${Translation.tr(o.text)}`.toLowerCase();
        return words.length > 0 && words.every(w => hay.includes(w));
    }).slice(0, 40)

    // "Group › Page" for an option's page.
    function pageTitle(id) {
        const p = Pages.find(id);
        if (!p)
            return id;
        const g = Pages.group(p.group);
        return g ? `${Translation.tr(g.title)} › ${Translation.tr(p.title)}` : Translation.tr(p.title);
    }
    function pageIcon(id) {
        return Pages.find(id)?.icon ?? "settings";
    }

    spacing: 8

    Section {
        visible: root.pageHits.length > 0
        icon: "search"
        title: Translation.tr("Pages")

        Repeater {
            model: root.pageHits

            ListRow {
                required property var modelData
                Layout.fillWidth: true
                clickable: true
                icon: modelData.icon
                title: Translation.tr(modelData.title)
                onClicked: root.picked(modelData.id, false)
            }
        }
    }

    Section {
        visible: root.optionHits.length > 0
        icon: "tune"
        title: Translation.tr("Options")

        Repeater {
            model: root.optionHits

            ListRow {
                required property var modelData
                Layout.fillWidth: true
                clickable: true
                icon: root.pageIcon(modelData.page)
                title: Translation.tr(modelData.text) || modelData.path
                subtitle: `${root.pageTitle(modelData.page)} · ${modelData.path}${modelData.advanced ? " · " + Translation.tr("advanced") : ""}`
                onClicked: root.picked(modelData.page, modelData.advanced)
            }
        }
    }

    StyledText {
        visible: root.pageHits.length === 0 && root.optionHits.length === 0
        Layout.margins: 14
        text: Translation.tr("Nothing found")
        color: Colors.m3outline
    }
}
