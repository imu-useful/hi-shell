import QtQuick
import QtQuick.Layouts
import qs.common
import qs.common.widgets
import qs.services

// The camera / microphone indicator: green for the microphone, orange for the camera,
// yellow for both. Fixed colours: they mean the same whatever the theme.
Rectangle {
    id: root

    readonly property string kind: Privacy.kind
    readonly property color tint: kind === "both" ? "#ffcc00" : kind === "camera" ? "#ff9500" : "#34c759"

    implicitHeight: 24
    implicitWidth: Math.max(implicitHeight, icons.implicitWidth + 12)
    radius: height / 2
    color: tint
    Behavior on color { ColorAnim {} }

    Row {
        id: icons
        anchors.centerIn: parent
        spacing: 2

        MaterialIcon {
            visible: root.kind === "mic" || root.kind === "both"
            icon: "mic"
            fill: 1
            iconSize: 16
            color: "#1c1b1f"
        }
        MaterialIcon {
            visible: root.kind === "camera" || root.kind === "both"
            icon: "videocam"
            fill: 1
            iconSize: 16
            color: "#1c1b1f"
        }
    }
}
