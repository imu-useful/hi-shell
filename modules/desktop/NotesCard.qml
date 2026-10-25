import QtQuick
import QtQuick.Layouts
import qs.common
import qs.common.widgets
import qs.services

// Sticky notes: + to add, tap to change color, × to remove.
DesktopCard {
    id: root

    property bool adding: false

    implicitWidth: 300
    implicitHeight: content.implicitHeight + 28

    ColumnLayout {
        id: content
        anchors.fill: parent
        anchors.margins: 14
        spacing: 8

        RowLayout {
            Layout.fillWidth: true
            StyledText {
                Layout.fillWidth: true
                text: Translation.tr("Notes")
                font.pixelSize: Appearance.font.size.titleLarge
                font.weight: Font.Medium
            }
            IconButton {
                implicitWidth: 36
                implicitHeight: 36
                filled: true
                icon: root.adding ? "close" : "add"
                onClicked: {
                    root.adding = !root.adding;
                    if (root.adding)
                        input.forceActiveFocus();
                }
            }
        }

        Rectangle {
            Layout.fillWidth: true
            visible: root.adding
            implicitHeight: 40
            radius: 20
            color: Colors.m3surfaceContainerHighest
            TextInput {
                id: input
                anchors.fill: parent
                anchors.leftMargin: 16
                anchors.rightMargin: 16
                verticalAlignment: TextInput.AlignVCenter
                font.family: Appearance.font.main
                font.pixelSize: Appearance.font.size.bodyMedium
                color: Colors.m3onSurface
                clip: true
                onAccepted: {
                    Notes.add(text);
                    text = "";
                    root.adding = false;
                }
            }
        }

        Repeater {
            model: Notes.notes

            Rectangle {
                required property var modelData
                required property int index
                readonly property color ink: [Colors.m3onPrimaryContainer, Colors.m3onSecondaryContainer, Colors.m3onTertiaryContainer][modelData.color]

                Layout.fillWidth: true
                implicitHeight: note.implicitHeight + 24
                radius: Appearance.rounding.large
                color: [Colors.m3primaryContainer, Colors.m3secondaryContainer, Colors.m3tertiaryContainer][modelData.color]

                StyledText {
                    id: note
                    anchors.left: parent.left
                    anchors.right: close.left
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.leftMargin: 14
                    text: modelData.text
                    wrapMode: Text.Wrap
                    elide: Text.ElideNone
                    color: parent.ink
                }
                StateLayer {
                    tint: parent.ink
                    onClicked: Notes.cycleColor(index)
                }
                IconButton {
                    id: close
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    implicitWidth: 32
                    implicitHeight: 32
                    icon: "close"
                    iconColor: parent.ink
                    onClicked: Notes.remove(index)
                }
            }
        }
    }
}
