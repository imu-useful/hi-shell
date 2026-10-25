import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import Quickshell.Widgets
import qs.common
import qs.common.widgets

// Focused window: app name over the title ("Desktop / Workspace N" when the
// focused workspace on this monitor is empty). Vertical bars show the icon only.
BarWidget {
    id: root

    readonly property HyprlandMonitor monitor: Hyprland.monitorFor(bar?.screen ?? null)
    readonly property HyprlandToplevel toplevel: Hyprland.activeToplevel
    // Only show a window that is on this monitor's active workspace.
    readonly property bool hasWindow: toplevel !== null && toplevel.workspace === monitor?.activeWorkspace
    readonly property string appId: hasWindow ? (toplevel.wayland?.appId ?? "") : ""
    readonly property var entry: appId ? DesktopEntries.heuristicLookup(appId) : null

    readonly property string appName: !hasWindow ? "Desktop" : entry?.name || appId || "Window"
    readonly property string title: !hasWindow ? `Workspace ${monitor?.activeWorkspace?.id ?? ""}` : toplevel.title || appName

    pill: false
    padding: 6
    Layout.fillWidth: true
    Layout.maximumWidth: 360
    contentWidth: vertical ? thickness : Math.max(appLabel.implicitWidth, titleLabel.implicitWidth)
    contentHeight: thickness - padding

    IconImage {
        visible: root.vertical
        anchors.centerIn: parent
        implicitSize: 20
        source: root.entry ? Quickshell.iconPath(root.entry.icon, true) : ""
    }

    ColumnLayout {
        visible: !root.vertical
        anchors.fill: parent
        spacing: -2

        Item { Layout.fillHeight: true }

        StyledText {
            id: appLabel
            Layout.fillWidth: true
            text: root.appName
            font.pixelSize: Appearance.font.size.labelSmall
            color: Colors.m3onSurfaceVariant
        }

        StyledText {
            id: titleLabel
            Layout.fillWidth: true
            text: root.title
            font.pixelSize: Appearance.font.size.normal
        }

        Item { Layout.fillHeight: true }
    }
}
