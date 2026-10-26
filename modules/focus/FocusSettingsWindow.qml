import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.common
import qs.common.widgets
import qs.services

// Focus Mode settings: a regular window (Hyprland manages it like any app), opened with
// `qs -c hi-shell ipc call focus settings` or from the launcher. The tabs edit the
// active profile; the chips at the top switch it. Closed and unavailable while a
// session runs. Everything is saved to ~/.config/hi-shell/focus_profiles.json.
Scope {
    id: root

    readonly property var tabs: [
        { id: "timer", icon: "timer", title: "Timer" },
        { id: "wallpaper", icon: "wallpaper", title: "Wallpaper" },
        { id: "lists", icon: "block", title: "Lists" },
        { id: "profiles", icon: "bookmarks", title: "Profiles" },
        { id: "todo", icon: "checklist", title: "To-Do" },
        { id: "exit", icon: "logout", title: "Exit" }
    ]

    Connections {
        target: Focus
        function onActiveChanged() {
            if (Focus.active)
                Focus.settingsOpen = false;
        }
    }

    LazyLoader {
        active: Focus.settingsOpen && !Focus.active

        FloatingWindow {
            id: window

            visible: true
            title: Translation.tr("Focus Mode · hi-shell")
            implicitWidth: 920
            implicitHeight: 680
            minimumSize: Qt.size(720, 520)
            color: Colors.m3surfaceContainerLow

            onClosed: Focus.settingsOpen = false

            Shortcut {
                sequence: "Escape"
                onActivated: Focus.settingsOpen = false
            }

            RowLayout {
                anchors.fill: parent
                anchors.margins: 16
                spacing: 16

                // --- Tabs ---
                ColumnLayout {
                    Layout.fillWidth: false
                    Layout.preferredWidth: 200
                    Layout.fillHeight: true
                    spacing: 6

                    RowLayout {
                        Layout.margins: 6
                        Layout.bottomMargin: 12
                        spacing: 12
                        Rectangle {
                            implicitWidth: 44
                            implicitHeight: 44
                            radius: 14
                            color: Colors.m3primaryContainer
                            MaterialIcon {
                                anchors.centerIn: parent
                                icon: "center_focus_strong"
                                fill: 1
                                color: Colors.m3onPrimaryContainer
                            }
                        }
                        ColumnLayout {
                            spacing: 0
                            StyledText {
                                text: Translation.tr("Focus Mode")
                                font.pixelSize: Appearance.font.size.titleMedium
                                font.weight: Font.Medium
                            }
                            StyledText {
                                text: Translation.tr("Settings")
                                font.pixelSize: Appearance.font.size.labelSmall
                                color: Colors.m3onSurfaceVariant
                            }
                        }
                    }

                    Repeater {
                        model: root.tabs

                        Rectangle {
                            required property var modelData
                            readonly property bool active: Focus.settingsTab === modelData.id

                            Layout.fillWidth: true
                            implicitHeight: 48
                            radius: 24
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
                                }
                            }
                            StateLayer {
                                onClicked: Focus.settingsTab = modelData.id
                            }
                        }
                    }

                    Item { Layout.fillHeight: true }
                }

                // --- Page ---
                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    spacing: 12

                    // Profile switcher, so it's clear which profile the tab edits.
                    Flow {
                        Layout.fillWidth: true
                        spacing: 8
                        Repeater {
                            model: Focus.profileIds
                            Chip {
                                required property string modelData
                                readonly property var profile: Focus.profiles[modelData]
                                text: profile.builtin ? Translation.tr(profile.name) : profile.name
                                icon: profile.icon
                                selected: Focus.activeId === modelData
                                onClicked: Focus.select(modelData)
                            }
                        }
                    }

                    StyledFlickable {
                        id: flick
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        contentHeight: page.implicitHeight + 24

                        Loader {
                            id: page
                            width: flick.width - 12
                            sourceComponent: ({
                                timer: timer, wallpaper: wallpaper, lists: lists,
                                profiles: profiles, todo: todo, exit: exit
                            })[Focus.settingsTab] ?? timer
                            onLoaded: {
                                flick.targetY = 0;
                                flick.contentY = 0;
                            }
                        }

                        Component { id: timer; TimerTab {} }
                        Component { id: wallpaper; WallpaperTab {} }
                        Component { id: lists; ListsTab {} }
                        Component { id: profiles; ProfilesTab {} }
                        Component { id: todo; TodoTab {} }
                        Component { id: exit; ExitTab {} }
                    }
                }
            }
        }
    }
}
