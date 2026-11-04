import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets
import qs.common
import qs.common.widgets
import qs.services

// The island's notification state: the app's icon and the title, and a bar along the bottom edge that
// runs out with the notification's timeout. Fills the pill it is put in; `implicitWidth` is the
// content's. A tap dismisses.
Item {
    id: root

    readonly property var notif: Island.notif
    property bool compact: false
    // The time left in coarse steps: every change redraws the bar, and the compositor blurs it again
    // behind it each time, which an integrated GPU feels. 24 steps are enough for a bar this short.
    readonly property real timeLeft: Math.round((notif?.remaining ?? 0) * 24) / 24

    readonly property string iconSource: {
        const icon = notif?.appIcon ?? "";
        if (!icon)
            return "";
        if (icon.startsWith("/") || icon.includes("://"))
            return icon.startsWith("/") ? "file://" + icon : icon;
        return Quickshell.iconPath(icon, true);
    }

    implicitWidth: row.implicitWidth + 24
    implicitHeight: 34

    RowLayout {
        id: row
        anchors.centerIn: parent
        spacing: 8

        Item {
            Layout.preferredWidth: 20
            Layout.preferredHeight: 20

            IconImage {
                id: appIcon
                anchors.fill: parent
                source: root.iconSource
                visible: status === Image.Ready
            }
            MaterialIcon {
                anchors.centerIn: parent
                visible: !appIcon.visible
                icon: root.notif?.critical ? "priority_high" : "notifications"
                fill: 1
                iconSize: 18
            }
        }

        StyledText {
            visible: !root.compact
            Layout.maximumWidth: 240
            text: root.notif?.summary || root.notif?.appName || ""
            font.pixelSize: Appearance.font.size.normal
            font.weight: Font.Medium
            elide: Text.ElideRight
        }
    }

    // Time left.
    Rectangle {
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 3
        x: parent.height / 2
        width: Math.max(0, (parent.width - parent.height) * root.timeLeft)
        height: 3
        radius: 1.5
        color: Colors.m3primary
    }
}
