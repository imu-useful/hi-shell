import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets
import qs.common
import qs.common.widgets
import qs.services

// Defaults: the program that opens each kind of file and link, and the terminal. A kind's list shows
// the programs that can open it; a program or command typed below sets it.
ColumnLayout {
    id: root

    spacing: 20

    Repeater {
        model: DefaultApps.categories

        Section {
            id: section

            required property var modelData
            readonly property bool isTerminal: modelData.id === "terminal"
            readonly property string chosen: isTerminal ? Config.options.apps.terminal : (DefaultApps.current[modelData.id] ?? "")
            readonly property var options: DefaultApps.candidates(modelData.id)
            readonly property string error: isTerminal ? "" : (DefaultApps.failed[modelData.id] ?? "")
            property bool expanded: false
            property bool notFound: false

            icon: modelData.icon
            title: Translation.tr(modelData.title)

            ListRow {
                Layout.fillWidth: true
                icon: "check_circle"
                title: Translation.tr("Opens with")
                subtitle: section.error !== "" ? section.error : (section.chosen !== "" ? DefaultApps.nameOf(section.chosen) : Translation.tr("Not set"))
                clickable: true
                onClicked: section.expanded = !section.expanded
                MaterialIcon {
                    icon: section.expanded ? "expand_less" : "expand_more"
                }
            }

            ColumnLayout {
                visible: section.expanded
                Layout.fillWidth: true
                Layout.leftMargin: 16
                Layout.rightMargin: 16
                spacing: 2

                Repeater {
                    model: section.options

                    Rectangle {
                        required property var modelData
                        readonly property string id: DefaultApps.fileName(modelData)
                        readonly property bool isChosen: section.isTerminal ? (modelData.id === section.chosen) : (id === section.chosen)
                        Layout.fillWidth: true
                        implicitHeight: 42
                        radius: Appearance.rounding.small
                        color: isChosen ? Colors.m3primaryContainer : "transparent"

                        IconImage {
                            id: appIcon
                            anchors.left: parent.left
                            anchors.leftMargin: 10
                            anchors.verticalCenter: parent.verticalCenter
                            implicitSize: 26
                            source: Quickshell.iconPath(modelData.icon ?? "", "application-x-executable")
                        }
                        StyledText {
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.left: appIcon.right
                            anchors.right: parent.right
                            anchors.leftMargin: 10
                            anchors.rightMargin: 12
                            text: modelData.name
                            elide: Text.ElideRight
                        }
                        StateLayer {
                            onClicked: {
                                DefaultApps.set(section.modelData.id, section.isTerminal ? modelData.id : id);
                                section.expanded = false;
                            }
                        }
                    }
                }

                StyledText {
                    visible: section.options.length === 0
                    Layout.fillWidth: true
                    Layout.topMargin: 6
                    text: Translation.tr("No installed app opens this")
                    color: Colors.m3outline
                }

                // A program or command that isn't in the list (typed, then Enter).
                TextRow {
                    Layout.fillWidth: true
                    Layout.topMargin: 6
                    icon: "keyboard_command_key"
                    title: Translation.tr("Or type a program or command")
                    subtitle: section.notFound ? Translation.tr("No program called “%1”").arg(section.typed) : ""
                    placeholder: section.isTerminal ? "kitty" : "firefox"
                    fieldWidth: 200
                    property string typed: ""
                    onEdited: text => {
                        typed = text;
                        const id = section.isTerminal ? text.trim() : DefaultApps.resolve(text);
                        section.notFound = id === "";
                        if (id !== "") {
                            DefaultApps.set(section.modelData.id, id);
                            section.expanded = false;
                            value = "";
                        }
                    }
                }
            }
        }
    }
}
