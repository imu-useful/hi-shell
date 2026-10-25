import QtQuick
import QtQuick.Layouts
import qs.common
import qs.common.widgets
import qs.services

// Pending tasks as tonal pills; tap a circle to complete, + to add.
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
                text: "To-Do"
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
                    Todo.add(text);
                    text = "";
                    root.adding = false;
                }
            }
        }

        Repeater {
            model: Todo.items.map((item, index) => ({ item, index })).filter(e => !e.item.done).slice(0, 6)

            Rectangle {
                required property var modelData
                Layout.fillWidth: true
                implicitHeight: 42
                radius: 21
                color: [Colors.m3primaryContainer, Colors.m3secondaryContainer, Colors.m3tertiaryContainer][modelData.index % 3]

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 6
                    anchors.rightMargin: 14
                    spacing: 6
                    IconButton {
                        implicitWidth: 32
                        implicitHeight: 32
                        icon: "radio_button_unchecked"
                        iconColor: Colors.m3onSurface
                        onClicked: Todo.toggle(modelData.index)
                    }
                    StyledText {
                        Layout.fillWidth: true
                        text: modelData.item.text
                    }
                }
            }
        }

        StyledText {
            visible: Todo.pending === 0 && !root.adding
            text: "All done"
            color: Colors.m3onSurfaceVariant
        }
    }
}
