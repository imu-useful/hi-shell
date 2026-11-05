import QtQuick
import QtQuick.Layouts
import qs.common
import qs.common.widgets
import qs.services

// Who is using the microphone and the camera (Privacy.micApps / cameraApps): a row for each in use, with
// its colour. In the island's hover card and under the calendar's month.
ColumnLayout {
    id: root

    property int textWidth: 220

    spacing: 8

    Repeater {
        model: [
            { icon: "mic", label: Translation.tr("Microphone"), apps: Privacy.micApps, tint: Privacy.micColor },
            { icon: "videocam", label: Translation.tr("Camera"), apps: Privacy.cameraApps, tint: Privacy.cameraColor }
        ].filter(r => r.apps.length > 0)

        RowLayout {
            required property var modelData
            Layout.fillWidth: true
            spacing: 10

            Rectangle {
                implicitWidth: 28
                implicitHeight: 28
                radius: 14
                color: modelData.tint

                MaterialIcon {
                    anchors.centerIn: parent
                    icon: modelData.icon
                    fill: 1
                    iconSize: 18
                    color: "#1c1b1f"
                }
            }
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 0

                StyledText {
                    text: modelData.label
                    font.pixelSize: Appearance.font.size.labelMedium
                    color: Colors.m3onSurfaceVariant
                }
                StyledText {
                    Layout.fillWidth: true
                    Layout.maximumWidth: root.textWidth
                    text: modelData.apps.join(", ")
                    font.weight: Font.Medium
                    wrapMode: Text.Wrap
                }
            }
        }
    }
}
