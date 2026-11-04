import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets
import qs.common
import qs.common.widgets
import qs.services

// Default applications: what opens a web page, a folder, a picture, a video, a document... Each kind
// lists the apps that can open it; a click makes one the default.
ColumnLayout {
    id: root

    spacing: 24

    Repeater {
        model: DefaultApps.categories

        Section {
            id: section

            required property var modelData
            readonly property string chosen: DefaultApps.current[modelData.id] ?? ""
            readonly property var options: DefaultApps.candidates(modelData.id)
            property bool expanded: false

            icon: modelData.icon
            title: Translation.tr(modelData.title)

            ListRow {
                Layout.fillWidth: true
                icon: "check_circle"
                title: Translation.tr("Opens with")
                subtitle: section.chosen !== "" ? section.chosen : Translation.tr("Not set")
                clickable: true
                onClicked: section.expanded = !section.expanded
                MaterialIcon {
                    icon: section.expanded ? "expand_less" : "expand_more"
                }
            }

            Flickable {
                visible: section.expanded
                Layout.fillWidth: true
                Layout.leftMargin: 16
                Layout.rightMargin: 16
                Layout.preferredHeight: visible ? Math.min(contentHeight, 320) : 0
                contentHeight: list.implicitHeight
                clip: true
                boundsBehavior: Flickable.StopAtBounds

                ColumnLayout {
                    id: list
                    width: parent.width
                    spacing: 2

                    Repeater {
                        model: section.options

                        Rectangle {
                            required property var modelData
                            readonly property bool isChosen: DefaultApps.fileName(modelData) === section.chosen
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
                                    DefaultApps.set(section.modelData.id, DefaultApps.fileName(modelData));
                                    section.expanded = false;
                                }
                            }
                        }
                    }

                    StyledText {
                        visible: section.options.length === 0
                        Layout.fillWidth: true
                        text: Translation.tr("No installed app opens this")
                        color: Colors.m3outline
                    }
                }
            }
        }
    }
}
