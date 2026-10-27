import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import qs.common
import qs.common.widgets
import qs.services

// Wallpaper picker: local folders (cached thumbnails) or online search
// (Wallhaven, Unsplash with a key), plus color scheme, mode and frame controls.
// Toggle: Super+R (hypr/hi-shell.lua), the bar's wallpaper button, or
// `qs -c hi-shell ipc call wallpaper toggleSelector`.
Scope {
    id: root

    readonly property bool open: ShellState.wallpaperSelectorOpen && !ShellState.zen
    property bool onlineTab: false
    property string filter: ""

    readonly property var shownLocal: filter === "" ? Wallpapers.local : Wallpapers.local.filter(w => w.name.toLowerCase().includes(filter.toLowerCase()))

    function setOpen(value) {
        ShellState.wallpaperSelectorOpen = value;
    }

    onOpenChanged: {
        if (open && Wallpapers.local.length === 0)
            Wallpapers.scan();
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
            mask: Region { item: card }

            WlrLayershell.namespace: "hi-shell-wallpapers"
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.keyboardFocus: root.open ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

            HyprlandFocusGrab {
                windows: [window]
                active: root.open
                onCleared: root.setOpen(false)
            }

            Shortcut {
                sequence: "Escape"
                onActivated: root.setOpen(false)
            }

            Rectangle {
                id: card

                anchors.centerIn: parent
                width: Math.min(parent.width - 80, 1180)
                height: Math.min(parent.height - 120, 780)
                radius: Appearance.rounding.extraLarge
                color: Appearance.translucent(Colors.m3surfaceContainerLow)
                border.width: 1
                border.color: Qt.alpha(Colors.m3outlineVariant, 0.6)

                opacity: loader.revealed ? 1 : 0
                scale: loader.revealed ? 1 : 0.85
                Behavior on opacity { EffectAnim {} }
                Behavior on scale { SpringAnim {} }

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 20
                    spacing: 14

                    // --- Header ---
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 10

                        MaterialIcon {
                            icon: "wallpaper"
                            color: Colors.m3primary
                        }
                        StyledText {
                            text: Translation.tr("Wallpapers")
                            font.pixelSize: Appearance.font.size.titleLarge
                        }

                        Item { Layout.fillWidth: true }

                        SegmentedButton {
                            model: [{ text: Translation.tr("Local"), icon: "folder" }, { text: Translation.tr("Online"), icon: "public" }]
                            currentIndex: root.onlineTab ? 1 : 0
                            onSelected: index => {
                                root.onlineTab = index === 1;
                                if (root.onlineTab && Wallpapers.online.length === 0)
                                    Wallpapers.search(1);
                            }
                        }
                        M3Button {
                            tonal: true
                            icon: "shuffle"
                            text: Translation.tr("Random")
                            onClicked: Wallpapers.random()
                        }

                        Item { Layout.fillWidth: true }

                        // Search: filters local names, or queries the online provider on Enter.
                        Rectangle {
                            Layout.preferredWidth: 280
                            implicitHeight: 40
                            radius: 20
                            color: Colors.m3surfaceContainerHighest

                            MaterialIcon {
                                id: searchIcon
                                anchors.left: parent.left
                                anchors.leftMargin: 12
                                anchors.verticalCenter: parent.verticalCenter
                                icon: "search"
                                iconSize: 20
                            }
                            TextInput {
                                id: search
                                anchors.left: searchIcon.right
                                anchors.right: parent.right
                                anchors.leftMargin: 8
                                anchors.rightMargin: 14
                                anchors.verticalCenter: parent.verticalCenter
                                font.family: Appearance.font.main
                                font.pixelSize: Appearance.font.size.bodyMedium
                                color: Colors.m3onSurface
                                clip: true
                                focus: true
                                onTextChanged: if (!root.onlineTab) root.filter = text
                                onAccepted: {
                                    if (root.onlineTab) {
                                        Wallpapers.query = text;
                                        Wallpapers.search(1);
                                    }
                                }

                                StyledText {
                                    anchors.fill: parent
                                    visible: search.text === ""
                                    text: root.onlineTab ? Translation.tr("Search %1…").arg(Wallpapers.provider === "unsplash" ? "Unsplash" : "Wallhaven") : Translation.trn("Filter %1 wallpaper", "Filter %1 wallpapers", Wallpapers.local.length)
                                    color: Colors.m3outline
                                }
                            }
                        }

                        IconButton {
                            icon: "close"
                            onClicked: root.setOpen(false)
                        }
                    }

                    // --- Online options ---
                    RowLayout {
                        Layout.fillWidth: true
                        visible: root.onlineTab
                        spacing: 8

                        SegmentedButton {
                            visible: Wallpapers.providers.length > 1
                            model: Wallpapers.providers.map(p => p === "unsplash" ? "Unsplash" : "Wallhaven")
                            currentIndex: Math.max(0, Wallpapers.providers.indexOf(Wallpapers.provider))
                            onSelected: index => {
                                Wallpapers.provider = Wallpapers.providers[index];
                                Wallpapers.search(1);
                            }
                        }
                        StyledText {
                            visible: Wallpapers.providers.length === 1
                            text: "Wallhaven"
                            color: Colors.m3onSurfaceVariant
                        }
                        SegmentedButton {
                            model: ["1080p", "2K", "4K"]
                            currentIndex: ["1920x1080", "2560x1440", "3840x2160"].indexOf(Wallpapers.resolution)
                            onSelected: index => {
                                Wallpapers.resolution = ["1920x1080", "2560x1440", "3840x2160"][index];
                                Wallpapers.search(1);
                            }
                        }
                        Item { Layout.fillWidth: true }
                        StyledText {
                            visible: Wallpapers.onlineError !== ""
                            text: Wallpapers.onlineError
                            color: Colors.m3error
                        }
                        Spinner {
                            visible: Wallpapers.searching || Wallpapers.downloading !== ""
                            implicitWidth: 22
                            implicitHeight: 22
                            color: Colors.m3primary
                        }
                        IconButton {
                            icon: "chevron_left"
                            enabled: Wallpapers.page > 1 && !Wallpapers.searching
                            onClicked: Wallpapers.search(Wallpapers.page - 1)
                        }
                        StyledText {
                            text: `${Wallpapers.page} / ${Wallpapers.lastPage}`
                            font.features: { "tnum": 1 }
                        }
                        IconButton {
                            icon: "chevron_right"
                            enabled: Wallpapers.page < Wallpapers.lastPage && !Wallpapers.searching
                            onClicked: Wallpapers.search(Wallpapers.page + 1)
                        }
                    }

                    // --- Grid ---
                    GridView {
                        id: grid

                        readonly property int columns: Math.max(2, Math.floor(width / 270))

                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        clip: true
                        cellWidth: width / columns
                        cellHeight: cellWidth * 9 / 16 + 12
                        boundsBehavior: Flickable.StopAtBounds
                        model: ScriptModel {
                            values: root.onlineTab ? Wallpapers.online : root.shownLocal
                            objectProp: root.onlineTab ? "id" : "path"
                        }

                        delegate: Item {
                            id: tile

                            required property var modelData
                            // From the item itself: right after a tab switch the old items are still shown briefly.
                            readonly property bool isOnline: modelData.url !== undefined
                            readonly property bool isCurrent: !isOnline && modelData.path === Wallpapers.current
                            readonly property bool busy: isOnline && Wallpapers.downloading === modelData.id

                            width: grid.cellWidth
                            height: grid.cellHeight

                            Rectangle {
                                anchors.fill: parent
                                anchors.margins: 6
                                radius: Appearance.rounding.large
                                color: Colors.m3surfaceContainerHigh
                                border.width: tile.isCurrent ? 3 : 0
                                border.color: Colors.m3primary
                                clip: true

                                Image {
                                    id: thumb
                                    anchors.fill: parent
                                    anchors.margins: tile.isCurrent ? 3 : 0
                                    source: tile.isOnline ? tile.modelData.thumb : `file://${tile.modelData.thumb}`
                                    fillMode: Image.PreserveAspectCrop
                                    asynchronous: true
                                    sourceSize.width: 480
                                    opacity: status === Image.Ready ? 1 : 0
                                    Behavior on opacity { EffectAnim {} }
                                    layer.enabled: true
                                    layer.smooth: true
                                }

                                // Label on hover
                                Rectangle {
                                    anchors.left: parent.left
                                    anchors.right: parent.right
                                    anchors.bottom: parent.bottom
                                    height: 30
                                    visible: hover.hovered
                                    color: Qt.alpha(Colors.m3surface, 0.75)
                                    StyledText {
                                        anchors.fill: parent
                                        anchors.leftMargin: 10
                                        anchors.rightMargin: 10
                                        text: tile.isOnline ? tile.modelData.resolution : tile.modelData.name
                                        font.pixelSize: Appearance.font.size.labelMedium
                                    }
                                }

                                Spinner {
                                    anchors.centerIn: parent
                                    visible: tile.busy
                                    implicitWidth: 32
                                    implicitHeight: 32
                                    color: Colors.m3primary
                                }

                                HoverHandler {
                                    id: hover
                                }
                                StateLayer {
                                    tint: Colors.m3onSurface
                                    onClicked: tile.isOnline ? Wallpapers.download(tile.modelData) : Wallpapers.set(tile.modelData.path)
                                }
                            }
                        }

                        StyledText {
                            anchors.centerIn: parent
                            visible: grid.count === 0
                            text: root.onlineTab ? (Wallpapers.searching ? Translation.tr("Searching…") : Translation.tr("Nothing found")) : Wallpapers.scanning ? Translation.tr("Making thumbnails…") : Translation.tr("No images in %1").arg(Config.options.wallpapers.directories.join(", "))
                            color: Colors.m3outline
                        }
                    }

                    // --- Colors & frame ---
                    Rectangle {
                        Layout.fillWidth: true
                        implicitHeight: colorRow.implicitHeight + 20
                        radius: Appearance.rounding.large
                        color: Colors.m3surfaceContainer

                        GridLayout {
                            id: colorRow
                            anchors.fill: parent
                            anchors.margins: 10
                            columns: 2
                            columnSpacing: 16
                            rowSpacing: 8

                            StyledText {
                                text: Translation.tr("Scheme")
                                font.pixelSize: Appearance.font.size.labelMedium
                                color: Colors.m3onSurfaceVariant
                            }
                            Flow {
                                Layout.fillWidth: true
                                spacing: 6
                                Repeater {
                                    model: Theme.schemes
                                    Chip {
                                        required property string modelData
                                        text: modelData.split("-").map(w => w[0].toUpperCase() + w.slice(1)).join(" ")
                                        selected: Config.options.appearance.scheme === modelData
                                        enabled: !Theme.busy || selected
                                        onClicked: Config.options.appearance.scheme = modelData
                                    }
                                }
                            }

                            StyledText {
                                text: Translation.tr("Mode")
                                font.pixelSize: Appearance.font.size.labelMedium
                                color: Colors.m3onSurfaceVariant
                            }
                            RowLayout {
                                spacing: 12
                                SegmentedButton {
                                    model: [{ text: Translation.tr("Light"), icon: "light_mode" }, { text: Translation.tr("Dark"), icon: "dark_mode" }, { text: Translation.tr("Auto"), icon: "brightness_auto" }]
                                    currentIndex: Config.options.appearance.autoMode ? 2 : Colors.dark ? 1 : 0
                                    onSelected: index => {
                                        Config.options.appearance.autoMode = index === 2;
                                        if (index < 2)
                                            Theme.setMode(index === 1 ? "dark" : "light");
                                    }
                                }
                                Row {
                                    spacing: 8
                                    StyledText {
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: Translation.tr("Transparency")
                                    }
                                    M3Switch {
                                        checked: Config.options.appearance.transparency
                                        onToggled: checked => Config.options.appearance.transparency = checked
                                    }
                                }
                                Spinner {
                                    visible: Theme.busy
                                    implicitWidth: 20
                                    implicitHeight: 20
                                    color: Colors.m3primary
                                }
                            }

                            StyledText {
                                text: Translation.tr("Frame")
                                font.pixelSize: Appearance.font.size.labelMedium
                                color: Colors.m3onSurfaceVariant
                            }
                            FramePicker {
                                Layout.fillWidth: true
                                Layout.margins: 0
                                current: Config.options.wallpapers.frame
                                onPicked: id => Config.options.wallpapers.frame = id
                            }
                        }
                    }
                }
            }
        }
    }
}
