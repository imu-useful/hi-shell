import QtQuick
import QtQuick.Layouts
import qs.common
import qs.common.widgets
import qs.services

// The installed icon, cursor and GTK themes (a tap applies one) and the fonts from the store; the
// Store page has more of each.
ColumnLayout {
    id: root

    // The tab shown (set by Settings from the tab row): installed (icons), cursors, gtk, fonts.
    property string tab: "installed"
    readonly property string kind: kindOf(tab)
    readonly property var store: Stores.of(kind)
    spacing: 24

    readonly property int gap: 10
    function columns(w, min) {
        return Math.max(1, Math.floor((w + gap) / (min + gap)));
    }
    function kindOf(t) {
        return t === "installed" ? "icons" : t;
    }

    // From `tab` itself: in onTabChanged the bindings that follow it may not have updated yet.
    function opened() {
        Stores.of(kindOf(tab)).refresh();
    }
    Component.onCompleted: opened()
    onTabChanged: opened()

    // A new size is applied once the slider stops.
    Timer {
        id: resize
        interval: 600
        onTriggered: if (Stores.cursors.current !== "") Stores.cursors.apply(Stores.cursors.current)
    }

    StyledText {
        visible: root.store.error !== ""
        Layout.fillWidth: true
        wrapMode: Text.WordWrap
        text: root.store.error
        color: Colors.m3error
    }

    Section {
        icon: ({ icons: "interests", cursors: "arrow_selector_tool", gtk: "web_asset", fonts: "font_download" })[root.kind]
        title: ({ icons: Translation.tr("Icon theme"), cursors: Translation.tr("Cursor theme"), gtk: Translation.tr("GTK theme"), fonts: Translation.tr("Fonts from the store") })[root.kind]

        StyledText {
            Layout.fillWidth: true
            Layout.margins: 14
            Layout.bottomMargin: 4
            wrapMode: Text.WordWrap
            text: ({
                icons: Translation.tr("Tap a theme to use it in the shell, KDE, GTK and Qt apps; the shell restarts to pick it up"),
                cursors: Translation.tr("Tap a theme to use it in Hyprland, GTK and KDE apps; the shell sets it again at every start"),
                gtk: Translation.tr("Tap a theme to use it in GTK apps; with GTK apps on in Style, the wallpaper's colors still go on top of it"),
                fonts: Translation.tr("Fonts installed from the store; pick where the shell uses one (a new font restarts the shell)")
            })[root.kind]
            font.pixelSize: Appearance.font.size.labelMedium
            color: Colors.m3onSurfaceVariant
        }
        SliderRow {
            visible: root.kind === "cursors"
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
        StyledText {
            visible: !root.store.loading && root.store.themes.length === 0
            Layout.fillWidth: true
            Layout.margins: 16
            horizontalAlignment: Text.AlignHCenter
            text: Translation.tr("Nothing installed yet")
            color: Colors.m3onSurfaceVariant
        }
        Flow {
            id: installedFlow
            Layout.fillWidth: true
            Layout.margins: 8
            spacing: root.gap
            readonly property int cols: root.columns(width, root.kind === "fonts" ? 280 : 220)
            readonly property real cardWidth: (width - root.gap * (cols - 1)) / cols
            Repeater {
                model: root.store.kind === "fonts" ? [] : root.store.themes
                IconThemeCard {
                    required property var modelData
                    store: root.store
                    theme: modelData
                    width: installedFlow.cardWidth
                }
            }
            Repeater {
                model: root.store.kind === "fonts" ? root.store.themes : []
                FontCard {
                    required property var modelData
                    item: modelData
                    width: installedFlow.cardWidth
                }
            }
        }
        ListRow {
            Layout.fillWidth: true
            icon: "storefront"
            title: ({ icons: Translation.tr("More icon themes"), cursors: Translation.tr("More cursor themes"), gtk: Translation.tr("More GTK themes"), fonts: Translation.tr("More fonts") })[root.kind]
            subtitle: root.kind === "fonts" ? Translation.tr("Every Google Fonts family, free") : Translation.tr("Hundreds of free themes from the KDE Store")
            M3Button {
                tonal: true
                text: Translation.tr("Store")
                onClicked: {
                    ShellState.settingsTab = root.kind;
                    ShellState.settingsPage = "store";
                }
            }
        }
    }
}
