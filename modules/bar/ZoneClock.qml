import QtQuick
import qs.common
import qs.common.widgets
import qs.services

// The time in another timezone: "zoneClock#tokyo" with { "zone": "Asia/Tokyo", "label": "TYO" } in Config
// bar.instances (label: empty = the city, "none" = no label). The time comes from services/WorldClock.qml,
// which also computes the zones of the bar's copies.
BarWidget {
    id: root

    readonly property string zone: instance.zone ?? ""
    readonly property var info: WorldClock.allClocks.find(c => c.zone === zone) ?? null
    readonly property string label: instance.label === "none" ? "" : (instance.label ?? info?.city ?? zone.split("/").pop().replace(/_/g, " "))

    shown: zone !== "" && info !== null
    padding: 10
    contentWidth: row.implicitWidth
    contentHeight: row.implicitHeight

    Grid {
        id: row
        anchors.centerIn: parent
        spacing: 6
        columns: root.vertical ? 1 : 2
        horizontalItemAlignment: Grid.AlignHCenter
        verticalItemAlignment: Grid.AlignVCenter

        StyledText {
            visible: root.label !== ""
            text: root.label
            color: Colors.m3onSurfaceVariant
            font.pixelSize: Appearance.font.size.labelMedium
        }
        StyledText {
            text: root.info?.time ?? ""
            font.pixelSize: Appearance.font.size.normal
        }
    }
}
