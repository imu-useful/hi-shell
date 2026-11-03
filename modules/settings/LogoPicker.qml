import QtQuick
import QtQuick.Layouts
import qs.common
import qs.common.widgets

// The distributions' logos to pick from: "auto" (this system's) first, then the ones shipped.
Flow {
    id: root

    property string current: "auto"
    readonly property var logos: ["archlinux", "nixos", "debian", "fedora", "cachyos", "endeavouros", "blackarch", "opensuse", "void"]
    signal picked(string name)

    spacing: 8

    Repeater {
        model: ["auto"].concat(root.logos)

        Rectangle {
            id: tile

            required property string modelData
            readonly property bool selected: root.current === modelData

            width: 56
            height: 56
            radius: 18
            color: selected ? Colors.m3primaryContainer : Colors.m3surfaceContainerHighest
            border.width: selected ? 2 : 0
            border.color: Colors.m3primary

            MaterialIcon {
                anchors.centerIn: parent
                visible: tile.modelData === "auto"
                icon: "auto_awesome"
                iconSize: 24
                color: tile.selected ? Colors.m3onPrimaryContainer : Colors.m3onSurfaceVariant
            }
            DistroLogo {
                anchors.centerIn: parent
                width: 32
                height: 32
                visible: tile.modelData !== "auto"
                logo: tile.modelData === "auto" ? "" : tile.modelData
                tint: tile.selected ? Colors.m3onPrimaryContainer : Colors.m3onSurfaceVariant
            }
            StateLayer {
                tint: Colors.m3onSurface
                onClicked: root.picked(tile.modelData)
            }
        }
    }
}
