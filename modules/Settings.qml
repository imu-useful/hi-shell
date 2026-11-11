import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import Quickshell.Wayland
import qs.common
import qs.common.widgets
import qs.common.shapes
import qs.modules.settings
import "settings/Pages.js" as Pages

// Settings panel (Super+Escape, the ⚙ in the right sidebar, launcher search,
// or `qs -c hi-shell ipc call settings open bar`). Everything is saved to
// ~/.config/hi-shell/config.json as you change it.
Scope {
    id: root

    // What is typed in the search box (it shows the matching pages and options instead of a page).
    property string searchQuery: ""

    readonly property bool open: ShellState.settingsOpen && !ShellState.zen

    // The page shown (the first one when the id is unknown).
    readonly property var currentPage: Pages.find(ShellState.settingsPage) ?? Pages.pages[0]

    function setOpen(value) {
        ShellState.settingsOpen = value;
    }

    // Show a page (and leave the search).
    // The tabs of the page shown, and the one picked (the first when none is).
    readonly property var currentTabs: Pages.tabsOf(root.currentPage.id)
    readonly property string currentTab: (currentTabs.find(t => t.id === ShellState.settingsTab) ?? currentTabs[0])?.id ?? ""

    // Show a page, or one tab of it (and leave the search). "page/tab" works too: `hi settings bar/island`.
    function goTo(pageId, tab = "") {
        const parts = pageId.split("/");
        root.searchQuery = "";
        ShellState.settingsTab = parts[1] ?? tab;
        ShellState.settingsPage = Pages.resolve(parts[0]);
    }

    // The next or previous tab of the page, wrapping around (Ctrl+PageDown, Ctrl+PageUp).
    function stepTab(delta) {
        const n = root.currentTabs.length;
        if (n < 2)
            return;
        const i = root.currentTabs.findIndex(t => t.id === root.currentTab);
        ShellState.settingsTab = root.currentTabs[(i + delta + n) % n].id;
    }

    // The next or previous page in the navigation's order, wrapping around (Ctrl+Tab, Ctrl+Shift+Tab).
    function step(delta) {
        const i = Pages.pages.indexOf(root.currentPage);
        root.goTo(Pages.pages[(i + delta + Pages.pages.length) % Pages.pages.length].id);
    }

    // A page in the navigation.
    component NavItem: Rectangle {
        id: navItem
        required property var modelData
        readonly property bool active: root.currentPage.id === modelData.id

        // Scroll the navigation so the page shown is in view (opened from search, ipc or Ctrl+Tab).
        function reveal() {
            const y = navItem.mapToItem(navList, 0, 0).y;
            if (y >= navFlick.contentY && y + height <= navFlick.contentY + navFlick.height)
                return;
            const centered = y - (navFlick.height - height) / 2;
            navFlick.contentY = Math.max(0, Math.min(centered, navFlick.contentHeight - navFlick.height));
        }
        // A moment later: a window that has just opened lays its navigation out first.
        onActiveChanged: if (active) revealTimer.restart()
        Component.onCompleted: if (active) revealTimer.restart()
        Timer {
            id: revealTimer
            interval: 60
            onTriggered: navItem.reveal()
        }

        Layout.fillWidth: true
        implicitHeight: 42
        radius: 21
        color: active ? Colors.m3secondaryContainer : "transparent"
        Behavior on color { ColorAnim {} }

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 16
            spacing: 14
            MaterialIcon {
                icon: modelData.icon
                fill: active ? 1 : 0
                iconSize: 20
                color: active ? Colors.m3onSecondaryContainer : Colors.m3onSurfaceVariant
            }
            StyledText {
                Layout.fillWidth: true
                text: Translation.tr(modelData.title)
                font.weight: active ? Font.Medium : Font.Normal
                color: active ? Colors.m3onSecondaryContainer : Colors.m3onSurface
                elide: Text.ElideRight
            }
        }
        StateLayer {
            onClicked: root.goTo(modelData.id)
        }
    }

    IpcHandler {
        target: "settings"

        function toggle(): void {
            root.setOpen(!root.open);
        }
        // A page id from modules/settings/Pages.js (home, bar, desktop, ...), or page/tab (bar/island).
        function open(page: string): void {
            if (page)
                root.goTo(page);
            root.setOpen(true);
        }
        // Open Settings with the search box filled: `hi settings search dock gap`.
        function search(text: string): void {
            root.searchQuery = text;
            root.setOpen(true);
        }
        function close(): void {
            root.setOpen(false);
        }
    }

    PanelLoader {
        id: loader
        shown: root.open

        PanelWindow {
            id: window

            screen: Quickshell.screens.find(s => s.name === Hyprland.focusedMonitor?.name) ?? Quickshell.screens[0]
            anchors.top: true
            anchors.bottom: true
            anchors.left: true
            anchors.right: true
            exclusionMode: ExclusionMode.Ignore
            color: "transparent"
            // The window takes clicks a little beyond the card too, so one that lands on its
            // edge isn't "outside" (which closes it, see the focus grab below).
            mask: Region { item: edge }

            WlrLayershell.namespace: "hi-shell-settings"
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.keyboardFocus: root.open ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None

            HyprlandFocusGrab {
                windows: [window]
                active: root.open
                onCleared: root.setOpen(false)
            }

            Shortcut {
                sequence: "Escape"
                onActivated: root.setOpen(false)
            }
            Shortcut {
                sequence: "Ctrl+Tab"
                onActivated: root.step(1)
            }
            Shortcut {
                // Qt sees Shift+Tab as Backtab.
                sequences: ["Ctrl+Shift+Tab", "Ctrl+Backtab"]
                onActivated: root.step(-1)
            }
            Shortcut {
                sequence: "Ctrl+F"
                onActivated: searchField.forceActiveFocus()
            }
            Shortcut {
                sequence: "Ctrl+PgDown"
                onActivated: root.stepTab(1)
            }
            Shortcut {
                sequence: "Ctrl+PgUp"
                onActivated: root.stepTab(-1)
            }

            Item {
                id: edge
                anchors.centerIn: parent
                width: card.width + 24
                height: card.height + 24

                MouseArea {
                    anchors.fill: parent
                    acceptedButtons: Qt.AllButtons
                }
            }

            Rectangle {
                id: card

                anchors.centerIn: parent
                width: Math.min(parent.width - 80, 1100)
                height: Math.min(parent.height - 100, 760)
                radius: Appearance.shape.panel
                color: Appearance.translucent(Colors.m3surfaceContainerLow)
                border.width: Appearance.edge
                border.color: Qt.alpha(Colors.m3outlineVariant, 0.6)

                opacity: loader.revealed ? 1 : 0
                scale: loader.revealed ? 1 : 0.85
                Behavior on opacity { EffectAnim {} }
                Behavior on scale { SpringAnim {} }

                RowLayout {
                    anchors.fill: parent
                    anchors.margins: 16
                    spacing: 16

                    // --- Navigation rail ---
                    ColumnLayout {
                        // Nested layouts with filling children default to filling too.
                        Layout.fillWidth: false
                        Layout.preferredWidth: 240
                        Layout.maximumWidth: 240
                        Layout.fillHeight: true
                        spacing: 6

                        RowLayout {
                            Layout.margins: 6
                            spacing: 10
                            // Five quick taps on the avatar open the first-run welcome again
                            // (for when it was skipped), like Android's developer options.
                            ShapeImage {
                                id: avatar
                                implicitWidth: 44
                                implicitHeight: 44
                                shape: "cookie9"
                                source: `file://${Paths.home}/.face`

                                property int taps: 0
                                readonly property int needed: 5

                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        avatar.taps++;
                                        tapReset.restart();
                                        bump.restart();
                                        if (avatar.taps >= avatar.needed) {
                                            avatar.taps = 0;
                                            root.setOpen(false);
                                            ShellState.showWelcome();
                                        }
                                    }
                                }
                                Timer {
                                    id: tapReset
                                    interval: 2000
                                    onTriggered: avatar.taps = 0
                                }
                                SequentialAnimation {
                                    id: bump
                                    NumberAnimation { target: avatar; property: "scale"; to: 0.86; duration: 70; easing.type: Easing.OutQuad }
                                    SpringAnim { target: avatar; property: "scale"; to: 1; duration: Appearance.anim.normal }
                                }
                            }
                            ColumnLayout {
                                spacing: 0
                                StyledText {
                                    text: Quickshell.env("USER")
                                    font.weight: Font.Medium
                                }
                                StyledText {
                                    // Counts down once the taps start.
                                    text: avatar.taps >= 2 ? Translation.trn("%1 more tap…", "%1 more taps…", avatar.needed - avatar.taps)
                                                           : Translation.tr("Arch Linux · Hyprland")
                                    font.pixelSize: Appearance.font.size.labelSmall
                                    color: Colors.m3onSurfaceVariant
                                }
                            }
                        }

                        // Search over the pages and every option (by name and description).
                        Rectangle {
                            Layout.fillWidth: true
                            Layout.leftMargin: 6
                            Layout.rightMargin: 6
                            implicitHeight: 38
                            radius: 19
                            color: Colors.m3surfaceContainerHighest
                            border.width: searchField.activeFocus ? 2 : 0
                            border.color: Colors.m3primary

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 12
                                anchors.rightMargin: 8
                                spacing: 8
                                MaterialIcon {
                                    icon: "search"
                                    iconSize: 18
                                    color: Colors.m3onSurfaceVariant
                                }
                                TextInput {
                                    id: searchField
                                    Layout.fillWidth: true
                                    text: root.searchQuery
                                    onTextChanged: root.searchQuery = text
                                    font.family: Appearance.font.main
                                    font.pixelSize: Appearance.font.size.bodyMedium
                                    color: Colors.m3onSurface
                                    clip: true
                                    selectByMouse: true

                                    StyledText {
                                        visible: searchField.text === ""
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: Translation.tr("Search settings")
                                        color: Colors.m3onSurfaceVariant
                                    }
                                }
                                IconButton {
                                    visible: searchField.text !== ""
                                    implicitWidth: 24
                                    implicitHeight: 24
                                    icon: "close"
                                    onClicked: searchField.text = ""
                                }
                            }
                        }

                        Item { implicitHeight: 6 }

                        // The pages: scrolled when there are more than fit in the card.
                        Flickable {
                            id: navFlick
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            clip: true
                            contentHeight: navList.implicitHeight
                            boundsBehavior: Flickable.StopAtBounds

                            ColumnLayout {
                                id: navList
                                width: navFlick.width
                                spacing: 6

                                // Pages with no group (Overview) first, then a label per group and its pages.
                                Repeater {
                                    model: Pages.inGroup("")
                                    NavItem {}
                                }
                                Item { implicitHeight: 4 }

                                Repeater {
                                    model: Pages.groups

                                    ColumnLayout {
                                        id: navGroup
                                        required property var modelData
                                        required property int index

                                        Layout.fillWidth: true
                                        spacing: 2

                                        StyledText {
                                            Layout.leftMargin: 16
                                            Layout.topMargin: navGroup.index === 0 ? 0 : 8
                                            Layout.bottomMargin: 2
                                            text: Translation.tr(navGroup.modelData.title)
                                            font.pixelSize: Appearance.font.size.labelMedium
                                            font.weight: Font.Medium
                                            color: Colors.m3primary
                                        }

                                        Repeater {
                                            model: Pages.inGroup(navGroup.modelData.id)

                                            NavItem {}
                                        }
                                    }
                                }
                            }
                        }
                    }

                    // --- Page ---
                    ColumnLayout {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        spacing: 12

                        // The page's group, title and what it is for (the query, while searching),
                        // and the config file.
                        RowLayout {
                            Layout.fillWidth: true
                            Layout.leftMargin: 4
                            Layout.topMargin: 6
                            spacing: 12

                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 2

                                readonly property bool searching: root.searchQuery.trim() !== ""

                                StyledText {
                                    text: parent.searching ? Translation.tr("Search") : Translation.tr(Pages.group(root.currentPage?.group)?.title ?? "")
                                visible: text !== ""
                                    font.pixelSize: Appearance.font.size.labelMedium
                                    font.weight: Font.Medium
                                    color: Colors.m3primary
                                }
                                StyledText {
                                    Layout.fillWidth: true
                                    text: parent.searching ? `«${root.searchQuery.trim()}»` : Translation.tr(root.currentPage?.title ?? "")
                                    font.family: Appearance.font.title
                                    font.pixelSize: Appearance.font.size.headlineSmall
                                    elide: Text.ElideRight
                                }
                                StyledText {
                                    Layout.fillWidth: true
                                    visible: !parent.searching && text !== ""
                                    text: Translation.tr(root.currentPage?.description ?? "")
                                    font.pixelSize: Appearance.font.size.bodyMedium
                                    color: Colors.m3onSurfaceVariant
                                    elide: Text.ElideRight
                                }
                            }

                            M3Button {
                                Layout.alignment: Qt.AlignTop
                                tonal: true
                                icon: "edit"
                                text: Translation.tr("Config file")
                                onClicked: {
                                    root.setOpen(false);
                                    Qt.openUrlExternally(`file://${Config.path}`);
                                }

                                // Right click copies the path of the config file.
                                MouseArea {
                                    anchors.fill: parent
                                    acceptedButtons: Qt.RightButton
                                    onClicked: {
                                        Quickshell.clipboardText = Config.path;
                                        ShellState.osdMessage("content_copy", Translation.tr("Config path copied"));
                                    }
                                }
                            }
                        }

                        // The page's tabs (pages that have them).
                        Item {
                            Layout.fillWidth: true
                            visible: root.currentTabs.length > 0 && root.searchQuery.trim() === ""
                            implicitHeight: 48

                            Rectangle {
                                anchors.left: parent.left
                                anchors.right: parent.right
                                anchors.bottom: parent.bottom
                                height: 1
                                color: Colors.m3outlineVariant
                            }
                            RowLayout {
                                anchors.fill: parent
                                spacing: 0

                                Repeater {
                                    model: root.currentTabs

                                    Item {
                                        id: tabItem
                                        required property var modelData
                                        readonly property bool active: root.currentTab === modelData.id

                                        Layout.fillHeight: true
                                        implicitWidth: tabRow.implicitWidth + 32

                                        RowLayout {
                                            id: tabRow
                                            anchors.centerIn: parent
                                            spacing: 8
                                            MaterialIcon {
                                                icon: tabItem.modelData.icon
                                                fill: tabItem.active ? 1 : 0
                                                iconSize: 20
                                                color: tabItem.active ? Colors.m3primary : Colors.m3onSurfaceVariant
                                            }
                                            StyledText {
                                                text: Translation.tr(tabItem.modelData.title)
                                                font.weight: Font.Medium
                                                color: tabItem.active ? Colors.m3primary : Colors.m3onSurfaceVariant
                                            }
                                        }
                                        Rectangle {
                                            anchors.bottom: parent.bottom
                                            anchors.horizontalCenter: parent.horizontalCenter
                                            width: tabRow.implicitWidth
                                            height: 3
                                            radius: 1.5
                                            color: Colors.m3primary
                                            opacity: tabItem.active ? 1 : 0
                                            Behavior on opacity { EffectAnim {} }
                                        }
                                        StateLayer {
                                            radius: Appearance.rounding.small
                                            onClicked: ShellState.settingsTab = tabItem.modelData.id
                                        }
                                    }
                                }
                                Item { Layout.fillWidth: true }
                            }
                        }

                        StyledFlickable {
                            id: flick

                            // A new tab starts at the top.
                            Connections {
                                target: root
                                function onCurrentTabChanged() {
                                    flick.targetY = 0;
                                    flick.contentY = 0;
                                }
                            }
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            contentHeight: page.implicitHeight + 24

                            Loader {
                                id: page
                                width: flick.width - 12
                                sourceComponent: root.searchQuery.trim() !== "" ? searchResults : ({
                            home: home, general: general, bar: bar, desktop: desktop,
                            style: style, motion: motion, panels: panels, modes: modes, wallpaper: wallpaper, dock: dock, notifications: notifications, power: power, contentfilter: contentfilter, services: services, hyprland: hyprland, autostart: autostart, keybinds: keybinds, screentime: screentime, rules: rules, defaultapps: defaultapps, about: about, lock: lock, sounds: sounds
                        })[root.currentPage.id] ?? home
                                onLoaded: {
                                    flick.targetY = 0;
                                    flick.contentY = 0;
                                    // A page that's a list of its own (Keybinds) is as tall as the window and scrolls itself.
                                    if (item.viewHeight !== undefined)
                                        item.viewHeight = Qt.binding(() => flick.height - 24);
                                    // A page with tabs shows the one picked in the tab row.
                                    if (item.tab !== undefined)
                                        item.tab = Qt.binding(() => root.currentTab);
                                }
                            }

                            Component { id: home; HomePage {} }
                            Component { id: general; GeneralPage {} }
                            Component { id: bar; BarPage {} }
                            Component { id: desktop; DesktopPage {} }
                            Component { id: style; StylePage {} }
                            Component { id: motion; MotionPage {} }
                            Component { id: panels; PanelsPage {} }
                            Component { id: modes; ModesPage {} }
                            Component { id: wallpaper; WallpaperPage {} }
                            Component { id: dock; DockPage {} }
                            Component { id: notifications; NotificationsPage {} }
                            Component { id: power; PowerPage {} }
                            Component { id: contentfilter; ContentFilterPage {} }
                            Component { id: services; ServicesPage {} }
                            Component { id: hyprland; HyprlandPage {} }
                            Component { id: autostart; AutostartPage {} }
                            Component { id: keybinds; KeybindsPage {} }
                            Component {
                                id: searchResults
                                SearchResults {
                                    query: root.searchQuery
                                    onPicked: (pageId, tab, advanced) => {
                                        if (advanced)
                                            Config.options.settingsAdvanced = true;
                                        root.goTo(pageId, tab);
                                    }
                                }
                            }
                            Component { id: screentime; ScreenTimePage {} }
                            Component { id: rules; RulesPage {} }
                            Component { id: defaultapps; DefaultAppsPage {} }
                            Component { id: about; AboutPage {} }
                            Component { id: lock; LockPage {} }
                            Component { id: sounds; SoundsPage {} }
                        }
                    }
                }
            }
        }
    }
}
