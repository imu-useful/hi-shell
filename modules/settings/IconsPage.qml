import QtQuick
import QtQuick.Layouts
import qs.common
import qs.common.widgets
import qs.services

// Icon themes: the installed ones (a tap applies one) and the KDE Store's, to install from.
ColumnLayout {
    id: root

    // The tab shown (set by Settings from the tab row): installed, store.
    property string tab: "installed"
    spacing: 24

    readonly property int gap: 10
    function columns(w, min) {
        return Math.max(1, Math.floor((w + gap) / (min + gap)));
    }

    Component.onCompleted: IconStore.refresh()
    onTabChanged: if (tab === "store" && IconStore.results.length === 0 && !IconStore.searching) IconStore.search()

    StyledText {
        visible: IconStore.error !== ""
        Layout.fillWidth: true
        wrapMode: Text.WordWrap
        text: IconStore.error
        color: Colors.m3error
    }

    Section {
        visible: root.tab === "installed"
        icon: "interests"
        title: Translation.tr("Icon theme")

        StyledText {
            Layout.fillWidth: true
            Layout.margins: 14
            Layout.bottomMargin: 4
            wrapMode: Text.WordWrap
            text: Translation.tr("Tap a theme to use it in the shell, KDE, GTK and Qt apps; the shell restarts to pick it up")
            font.pixelSize: Appearance.font.size.labelMedium
            color: Colors.m3onSurfaceVariant
        }
        Spinner {
            visible: IconStore.loading && IconStore.themes.length === 0
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
                model: IconStore.themes
                IconThemeCard {
                    required property var modelData
                    theme: modelData
                    width: (installedFlow.width - root.gap * (installedFlow.cols - 1)) / installedFlow.cols
                }
            }
        }
        ListRow {
            Layout.fillWidth: true
            icon: "storefront"
            title: Translation.tr("More icon themes")
            subtitle: Translation.tr("Hundreds of free themes from the KDE Store")
            M3Button {
                tonal: true
                text: Translation.tr("Store")
                onClicked: ShellState.settingsTab = "store"
            }
        }
    }

    Section {
        visible: root.tab === "store"
        icon: "storefront"
        title: Translation.tr("KDE Store")

        RowLayout {
            Layout.fillWidth: true
            Layout.margins: 12
            spacing: 8

            Rectangle {
                Layout.fillWidth: true
                implicitHeight: 40
                radius: 20
                color: Colors.m3surfaceContainerHighest
                border.width: field.activeFocus ? 2 : 0
                border.color: Colors.m3primary

                MaterialIcon {
                    id: searchIcon
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
                    text: IconStore.query
                    onAccepted: IconStore.search(text, undefined)

                    StyledText {
                        anchors.fill: parent
                        verticalAlignment: Text.AlignVCenter
                        visible: field.text === ""
                        text: Translation.tr("Search icon themes: papirus, tela, mac…")
                        color: Colors.m3outline
                    }
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
            currentIndex: Math.max(0, sorts.indexOf(IconStore.sort))
            onSelected: index => IconStore.search(field.text, sorts[index])
        }
        StyledText {
            visible: !IconStore.searching && IconStore.results.length === 0 && IconStore.error === ""
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
                model: IconStore.results
                StoreThemeCard {
                    required property var modelData
                    item: modelData
                    width: (storeFlow.width - root.gap * (storeFlow.cols - 1)) / storeFlow.cols
                }
            }
        }
        Spinner {
            visible: IconStore.searching
            Layout.alignment: Qt.AlignHCenter
            Layout.margins: 16
            implicitWidth: 28
            implicitHeight: 28
        }
        M3Button {
            visible: IconStore.hasMore && !IconStore.searching
            Layout.alignment: Qt.AlignHCenter
            Layout.margins: 12
            tonal: true
            icon: "expand_more"
            text: Translation.tr("Show more (%1 left)").arg(IconStore.total - IconStore.results.length)
            onClicked: IconStore.more()
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
