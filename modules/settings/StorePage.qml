import QtQuick
import QtQuick.Layouts
import qs.common
import qs.common.widgets
import qs.services

// Stores: icon, cursor and GTK themes from the KDE Store, fonts from Google Fonts. Search, sort,
// more pages, install with progress; what's installed is picked on the Themes page (or right here).
ColumnLayout {
    id: root

    // The tab shown (set by Settings from the tab row): icons, cursors, gtk, fonts.
    property string tab: "icons"
    readonly property var store: Stores.of(tab)
    readonly property bool fonts: tab === "fonts"
    spacing: 24

    readonly property int gap: 10
    function columns(w, min) {
        return Math.max(1, Math.floor((w + gap) / (min + gap)));
    }

    // From `tab` itself: in onTabChanged the bindings that follow it may not have updated yet.
    function opened() {
        const s = Stores.of(tab);
        s.refresh();
        if (s.results.length === 0 && !s.searching)
            s.search();
    }
    Component.onCompleted: opened()
    onTabChanged: opened()

    readonly property var sorts: fonts ? ["popular", "new", "name"] : ["popular", "new", "rating", "name"]
    readonly property var sortButtons: fonts ? [
        { text: Translation.tr("Popular"), icon: "trending_up" },
        { text: Translation.tr("Newest"), icon: "new_releases" },
        { text: Translation.tr("A–Z"), icon: "sort_by_alpha" }
    ] : [
        { text: Translation.tr("Popular"), icon: "trending_up" },
        { text: Translation.tr("Newest"), icon: "new_releases" },
        { text: Translation.tr("Rating"), icon: "star" },
        { text: Translation.tr("A–Z"), icon: "sort_by_alpha" }
    ]
    readonly property var categories: [
        { value: "", text: Translation.tr("All") },
        { value: "sans-serif", text: Translation.tr("sans-serif") },
        { value: "serif", text: Translation.tr("serif") },
        { value: "monospace", text: Translation.tr("monospace") },
        { value: "display", text: Translation.tr("display") },
        { value: "handwriting", text: Translation.tr("handwriting") }
    ]

    StyledText {
        visible: root.store.error !== ""
        Layout.fillWidth: true
        wrapMode: Text.WordWrap
        text: root.store.error
        color: Colors.m3error
    }

    Section {
        icon: "storefront"
        title: ({ icons: Translation.tr("KDE Store: icons"), cursors: Translation.tr("KDE Store: cursors"), gtk: Translation.tr("KDE Store: GTK themes"), fonts: Translation.tr("Google Fonts") })[root.tab] ?? ""

        Rectangle {
            Layout.fillWidth: true
            Layout.margins: 12
            implicitHeight: 40
            radius: 20
            color: Colors.m3surfaceContainerHighest
            border.width: field.activeFocus ? 2 : 0
            border.color: Colors.m3primary

            MaterialIcon {
                anchors.left: parent.left
                anchors.leftMargin: 12
                anchors.verticalCenter: parent.verticalCenter
                icon: "search"
                iconSize: 20
                color: Colors.m3onSurfaceVariant
            }
            TextInput {
                id: field
                anchors.fill: parent
                anchors.leftMargin: 40
                anchors.rightMargin: 14
                verticalAlignment: TextInput.AlignVCenter
                font.family: Appearance.font.main
                font.pixelSize: Appearance.font.size.bodyMedium
                color: Colors.m3onSurface
                clip: true
                selectByMouse: true
                text: root.store.query
                onAccepted: root.store.search(text, undefined)

                StyledText {
                    anchors.fill: parent
                    verticalAlignment: Text.AlignVCenter
                    visible: field.text === ""
                    text: ({
                        icons: Translation.tr("Search icon themes: papirus, tela, mac…"),
                        cursors: Translation.tr("Search cursor themes: bibata, breeze, mac…"),
                        gtk: Translation.tr("Search GTK themes: nordic, orchis, catppuccin…"),
                        fonts: Translation.tr("Search fonts: inter, roboto, fira…")
                    })[root.tab] ?? ""
                    color: Colors.m3outline
                }
            }
        }
        SegmentedButton {
            Layout.leftMargin: 12
            Layout.bottomMargin: 4
            model: root.sortButtons
            currentIndex: Math.max(0, root.sorts.indexOf(root.store.sort))
            onSelected: index => root.store.search(field.text, root.sorts[index])
        }
        Flow {
            visible: root.fonts
            Layout.fillWidth: true
            Layout.leftMargin: 12
            Layout.rightMargin: 12
            spacing: 6
            Repeater {
                model: root.categories
                Chip {
                    required property var modelData
                    text: modelData.text
                    selected: root.store.filter === modelData.value
                    onClicked: root.store.search(field.text, undefined, modelData.value)
                }
            }
        }
        StyledText {
            visible: !root.store.searching && root.store.results.length === 0 && root.store.error === ""
            Layout.fillWidth: true
            Layout.margins: 16
            horizontalAlignment: Text.AlignHCenter
            text: Translation.tr("Nothing found")
            color: Colors.m3onSurfaceVariant
        }
        Flow {
            id: storeFlow
            Layout.fillWidth: true
            Layout.margins: 8
            spacing: root.gap
            readonly property int cols: root.columns(width, root.fonts ? 280 : 250)
            readonly property real cardWidth: (width - root.gap * (cols - 1)) / cols
            Repeater {
                model: root.store.kind === "fonts" ? [] : root.store.results
                StoreThemeCard {
                    required property var modelData
                    store: root.store
                    item: modelData
                    width: storeFlow.cardWidth
                }
            }
            Repeater {
                model: root.store.kind === "fonts" ? root.store.results : []
                FontCard {
                    required property var modelData
                    item: modelData
                    width: storeFlow.cardWidth
                }
            }
        }
        Spinner {
            visible: root.store.searching
            Layout.alignment: Qt.AlignHCenter
            Layout.margins: 16
            implicitWidth: 28
            implicitHeight: 28
        }
        M3Button {
            visible: root.store.hasMore && !root.store.searching
            Layout.alignment: Qt.AlignHCenter
            Layout.margins: 12
            tonal: true
            icon: "expand_more"
            text: Translation.tr("Show more (%1 left)").arg(root.store.total - root.store.results.length)
            onClicked: root.store.more()
        }
        StyledText {
            Layout.fillWidth: true
            Layout.margins: 14
            Layout.topMargin: 0
            wrapMode: Text.WordWrap
            text: root.fonts ? Translation.tr("Fonts come from Google Fonts (through google-webfonts-helper) and are saved to ~/.local/share/fonts/hi-shell")
                : root.tab === "gtk" ? Translation.tr("Themes are made by their authors and come from store.kde.org; they are saved to ~/.local/share/themes")
                : Translation.tr("Themes are made by their authors and come from store.kde.org; they are saved to ~/.local/share/icons")
            font.pixelSize: Appearance.font.size.labelMedium
            color: Colors.m3onSurfaceVariant
        }
    }
}
