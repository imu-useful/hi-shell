import QtQuick
import QtQuick.Layouts
import qs.common
import qs.common.widgets
import qs.services

// Icon and cursor themes: the installed ones (a tap applies one) and the KDE Store's, to install from.
ColumnLayout {
    id: root

    // The tab shown (set by Settings from the tab row): installed, store, cursors, cursorstore.
    property string tab: "installed"
    readonly property bool cursorTab: tab === "cursors" || tab === "cursorstore"
    readonly property bool storeTab: tab === "store" || tab === "cursorstore"
    readonly property var store: cursorTab ? IconStore.cursors : IconStore.icons
    spacing: 24

    readonly property int gap: 10
    function columns(w, min) {
        return Math.max(1, Math.floor((w + gap) / (min + gap)));
    }

    // From `tab` itself: in onTabChanged the bindings that follow it may not have updated yet.
    function opened() {
        const s = tab === "cursors" || tab === "cursorstore" ? IconStore.cursors : IconStore.icons;
        if (s.themes.length === 0)
            s.refresh();
        if ((tab === "store" || tab === "cursorstore") && s.results.length === 0 && !s.searching)
            s.search();
    }
    Component.onCompleted: opened()
    onTabChanged: opened()

    // A new size is applied once the slider stops.
    Timer {
        id: resize
        interval: 600
        onTriggered: if (IconStore.cursors.current !== "") IconStore.cursors.apply(IconStore.cursors.current)
    }

    StyledText {
        visible: root.store.error !== ""
        Layout.fillWidth: true
        wrapMode: Text.WordWrap
        text: root.store.error
        color: Colors.m3error
    }

    Section {
        visible: !root.storeTab
        icon: root.cursorTab ? "arrow_selector_tool" : "interests"
        title: root.cursorTab ? Translation.tr("Cursor theme") : Translation.tr("Icon theme")

        StyledText {
            Layout.fillWidth: true
            Layout.margins: 14
            Layout.bottomMargin: 4
            wrapMode: Text.WordWrap
            text: root.cursorTab ? Translation.tr("Tap a theme to use it in Hyprland, GTK and KDE apps; the shell sets it again at every start")
                : Translation.tr("Tap a theme to use it in the shell, KDE, GTK and Qt apps; the shell restarts to pick it up")
            font.pixelSize: Appearance.font.size.labelMedium
            color: Colors.m3onSurfaceVariant
        }
        SliderRow {
            visible: root.cursorTab
            icon: "format_size"
            title: Translation.tr("Cursor size")
            value: Config.options.appearance.cursorSize
            from: 16; to: 64; step: 4; suffix: Translation.tr(" px")
            onMoved: value => {
                Config.options.appearance.cursorSize = value;
                resize.restart();
            }
        }
        Spinner {
            visible: root.store.loading && root.store.themes.length === 0
            Layout.alignment: Qt.AlignHCenter
            Layout.margins: 16
            implicitWidth: 28
            implicitHeight: 28
        }
        Flow {
            id: installedFlow
            Layout.fillWidth: true
            Layout.margins: 8
            spacing: root.gap
            readonly property int cols: root.columns(width, 220)
            Repeater {
                model: root.store.themes
                IconThemeCard {
                    required property var modelData
                    store: root.store
                    theme: modelData
                    width: (installedFlow.width - root.gap * (installedFlow.cols - 1)) / installedFlow.cols
                }
            }
        }
        ListRow {
            Layout.fillWidth: true
            icon: "storefront"
            title: root.cursorTab ? Translation.tr("More cursor themes") : Translation.tr("More icon themes")
            subtitle: Translation.tr("Hundreds of free themes from the KDE Store")
            M3Button {
                tonal: true
                text: Translation.tr("Store")
                onClicked: ShellState.settingsTab = root.cursorTab ? "cursorstore" : "store"
            }
        }
    }

    Section {
        visible: root.storeTab
        icon: "storefront"
        title: root.cursorTab ? Translation.tr("KDE Store: cursors") : Translation.tr("KDE Store: icons")

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
                    text: root.cursorTab ? Translation.tr("Search cursor themes: bibata, breeze, mac…") : Translation.tr("Search icon themes: papirus, tela, mac…")
                    color: Colors.m3outline
                }
            }
        }
        SegmentedButton {
            Layout.leftMargin: 12
            Layout.bottomMargin: 4
            readonly property var sorts: ["popular", "new", "rating", "name"]
            model: [
                { text: Translation.tr("Popular"), icon: "trending_up" },
                { text: Translation.tr("Newest"), icon: "new_releases" },
                { text: Translation.tr("Rating"), icon: "star" },
                { text: Translation.tr("A–Z"), icon: "sort_by_alpha" }
            ]
            currentIndex: Math.max(0, sorts.indexOf(root.store.sort))
            onSelected: index => root.store.search(field.text, sorts[index])
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
            readonly property int cols: root.columns(width, 250)
            Repeater {
                model: root.store.results
                StoreThemeCard {
                    required property var modelData
                    store: root.store
                    item: modelData
                    width: (storeFlow.width - root.gap * (storeFlow.cols - 1)) / storeFlow.cols
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
            text: Translation.tr("Themes are made by their authors and come from store.kde.org; they are saved to ~/.local/share/icons")
            font.pixelSize: Appearance.font.size.labelMedium
            color: Colors.m3onSurfaceVariant
        }
    }
}
